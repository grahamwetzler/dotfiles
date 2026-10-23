#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx>=0.28"]
# ///
"""Upload everything in ~/Inbox to Paperless, then move it to the Trash.

launchd runs this (QueueDirectories) whenever the inbox is non-empty and keeps
relaunching it until the inbox is empty, so every file has to leave: trashed once
Paperless reports it consumed, or moved to FAILED_DIR if Paperless rejects it.
Files stay put only for transient problems (still being written, server down),
so the next launchd run retries them.
"""

import mimetypes
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import httpx

INBOX = Path(os.environ.get("PAPERLESS_INBOX", "~/Inbox")).expanduser()
FAILED_DIR = Path(os.environ.get("PAPERLESS_FAILED_DIR", "~/Inbox Failed")).expanduser()
KEYCHAIN_SERVICE = os.environ.get("KEYCHAIN_SERVICE", "paperless-inbox")

# A file modified this recently may still be mid-copy or mid-download
SETTLE_SECONDS = 10
PARTIAL_SUFFIXES = {".crdownload", ".download", ".part", ".tmp", ".icloud"}
TASK_POLL_SECONDS = 3
# Just past Paperless's own 1800s consume limit, so Paperless gets the final say
TASK_TIMEOUT_SECONDS = 1900


class Rejected(Exception):
    """Paperless refused the document; retrying won't help."""


def log(msg: str) -> None:
    print(f"{datetime.now():%F %T} {msg}", flush=True)


def setting(env_var: str, account: str) -> str:
    """Read a setting from the environment, else from the keychain."""
    if value := os.environ.get(env_var):
        return value
    result = subprocess.run(
        ["/usr/bin/security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", account, "-w"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise LookupError(f"no {account!r} in keychain service {KEYCHAIN_SERVICE!r}, and ${env_var} is unset")
    return result.stdout.strip()


def is_settled(path: Path) -> bool:
    if path.suffix.lower() in PARTIAL_SUFFIXES:
        return False
    if time.time() - path.stat().st_mtime < SETTLE_SECONDS:
        return False
    # A writer can stall past SETTLE_SECONDS, but it still has the file open for
    # writing ("w" or "u" access); readers like Quick Look shouldn't block uploads
    access = subprocess.run(
        ["/usr/sbin/lsof", "-w", "-F", "a", "--", str(path)], capture_output=True, text=True,
    ).stdout.splitlines()
    return not {"aw", "au"} & set(access)


def upload(client: httpx.Client, path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    with path.open("rb") as f:
        r = client.post("/api/documents/post_document/", files={"document": (path.name, f, mime)})
    if r.status_code == 400:
        raise Rejected(f"upload refused: {r.text}")
    r.raise_for_status()
    return r.json()


def wait_for_task(client: httpx.Client, task_id: str) -> int:
    """Wait for Paperless to finish consuming; return the new document's id."""
    deadline = time.monotonic() + TASK_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        try:
            r = client.get("/api/tasks/", params={"task_id": task_id})
            r.raise_for_status()
        except (httpx.TransportError, httpx.HTTPStatusError) as e:
            # The file is already uploaded, so ride out blips rather than give up
            log(f"checking task {task_id}: {e!r}")
            time.sleep(TASK_POLL_SECONDS)
            continue
        # The task can take a moment to show up, so no results means still pending
        if tasks := r.json()["results"]:
            task = tasks[0]
            result = task["result_data"] or {}
            if task["status"] == "success":
                return result.get("document_id") or task["related_document_ids"][0]
            if "duplicate_of" in result:
                raise Rejected(f"duplicate of document {result['duplicate_of']}")
            if task["status"] in ("failure", "revoked"):
                raise Rejected(f"consumption failed: {result.get('error_message', task['status'])}")
        time.sleep(TASK_POLL_SECONDS)
    raise Rejected(f"task {task_id} still unfinished after {TASK_TIMEOUT_SECONDS}s; check Paperless")


def move_to_failed(path: Path) -> None:
    FAILED_DIR.mkdir(parents=True, exist_ok=True)
    dest = FAILED_DIR / path.name
    if dest.exists():
        dest = dest.with_stem(f"{dest.stem} {datetime.now():%Y%m%d-%H%M%S}")
    shutil.move(path, dest)
    log(f"moved to {dest}")


def main() -> int:
    if not INBOX.is_dir():
        log(f"inbox {INBOX} does not exist")
        return 1

    # Finder litters folders with .DS_Store, which would keep launchd relaunching us
    (INBOX / ".DS_Store").unlink(missing_ok=True)

    entries = sorted(INBOX.iterdir())
    if not entries:
        return 0

    try:
        url = setting("PAPERLESS_URL", "url").rstrip("/")
        token = setting("PAPERLESS_TOKEN", "api-token")
    except LookupError as e:
        log(str(e))
        return 1

    status = 0
    headers = {"Authorization": f"Token {token}"}
    with httpx.Client(base_url=url, headers=headers, timeout=60) as client:
        for path in entries:
            if path.is_dir() or path.name.startswith("."):
                log(f"{path.name}: hidden file or directory, not uploading")
                move_to_failed(path)
                continue
            if not is_settled(path):
                log(f"{path.name}: still being written, will retry")
                continue

            try:
                task_id = upload(client, path)
            except Rejected as e:
                log(f"{path.name}: {e}")
                move_to_failed(path)
                continue
            except httpx.HTTPStatusError as e:
                if e.response.status_code in (401, 403):
                    log(f"Paperless rejected the API token ({e.response.status_code}); stopping")
                    return 1
                log(f"{path.name}: {e}; will retry")
                status = 1
                continue
            except httpx.TransportError as e:
                log(f"{path.name}: cannot reach Paperless ({e!r}); will retry")
                return 1

            # Paperless has the file now, so whatever happens it must leave the inbox;
            # otherwise launchd's next run would upload it again
            try:
                doc_id = wait_for_task(client, task_id)
                log(f"{path.name}: uploaded as document {doc_id}")
                subprocess.run(["/usr/bin/trash", str(path)], check=True)
            except Exception as e:
                log(f"{path.name}: uploaded as task {task_id} but not confirmed: {e}")
                move_to_failed(path)

    return status


if __name__ == "__main__":
    sys.exit(main())
