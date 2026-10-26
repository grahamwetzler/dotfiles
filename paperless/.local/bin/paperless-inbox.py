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


def open_for_writing(path: Path) -> bool:
    # "w" or "u" access; readers like Quick Look shouldn't block uploads
    access = subprocess.run(
        ["/usr/sbin/lsof", "-w", "-F", "a", "--", str(path)], capture_output=True, text=True,
    ).stdout.splitlines()
    return bool({"aw", "au"} & set(access))


def is_quiet(path: Path) -> bool:
    """Neither modified in the last SETTLE_SECONDS nor open for writing."""
    try:
        # A symlink's target is what gets uploaded, so go by its age; a dangling
        # one has no target, so go by the link's own age rather than wait forever
        st = path.stat() if path.exists() else path.lstat()
        if time.time() - st.st_mtime < SETTLE_SECONDS:
            return False
    except FileNotFoundError:
        # Renamed or removed since it was listed, so something is still changing
        return False
    # A writer can stall past SETTLE_SECONDS, but it still has the file open
    return not open_for_writing(path)


def is_settled(path: Path) -> bool:
    if path.suffix.lower() in PARTIAL_SUFFIXES:
        return False
    return is_quiet(path)


def is_hidden(path: Path, root: Path) -> bool:
    return any(part.startswith(".") for part in path.relative_to(root).parts)


def busy(entry: Path) -> Path | None:
    """Return something under entry that's still changing, if anything is."""
    for p in [entry, *entry.rglob("*")]:
        # Hidden files only count while recent or open, so a stale .DS_Store or an
        # abandoned .part file can't hold a folder back forever
        if not (is_quiet(p) if is_hidden(p, entry) else is_settled(p)):
            return p
    return None


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


class Unreachable(Exception):
    """Paperless is down or refused the token; give up on this run."""


def move_to_failed(path: Path) -> None:
    # Keep the file's folder path so a rejected file from a dropped folder stays
    # recognizable, renaming any folder whose name is already taken by a file
    stamp = f"{datetime.now():%Y%m%d-%H%M%S}"
    rel = path.relative_to(INBOX)
    dest = FAILED_DIR
    for part in rel.parts[:-1]:
        dest /= part
        if dest.exists() and not dest.is_dir():
            dest = dest.with_name(f"{dest.name} {stamp}")
    dest.mkdir(parents=True, exist_ok=True)
    dest /= rel.name
    if dest.exists():
        dest = dest.with_stem(f"{dest.stem} {stamp}")
    shutil.move(path, dest)
    log(f"moved to {dest}")


def documents_in(folder: Path) -> list[Path]:
    """Every file under folder, ignoring hidden files and anything in hidden folders."""
    return sorted(p for p in folder.rglob("*") if p.is_file() and not is_hidden(p, folder))


def process(client: httpx.Client, path: Path) -> bool:
    """Upload one file, then trash it or move it to FAILED_DIR. Return False to retry it later."""
    name = path.relative_to(INBOX)
    try:
        task_id = upload(client, path)
    except Rejected as e:
        log(f"{name}: {e}")
        move_to_failed(path)
        return True
    except httpx.HTTPStatusError as e:
        if e.response.status_code in (401, 403):
            raise Unreachable(f"Paperless rejected the API token ({e.response.status_code})")
        log(f"{name}: {e}; will retry")
        return False
    except httpx.TransportError as e:
        raise Unreachable(f"cannot reach Paperless ({e!r})")

    # Paperless has the file now, so whatever happens it must leave the inbox;
    # otherwise launchd's next run would upload it again
    try:
        doc_id = wait_for_task(client, task_id)
        log(f"{name}: uploaded as document {doc_id}")
        subprocess.run(["/usr/bin/trash", str(path)], check=True)
    except Exception as e:
        log(f"{name}: uploaded as task {task_id} but not confirmed: {e}")
        move_to_failed(path)
    return True


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
        for entry in entries:
            if entry.name.startswith("."):
                log(f"{entry.name}: hidden, not uploading")
                move_to_failed(entry)
                continue

            # A dropped folder is handled as a whole, and only once nothing in it
            # (including the folder itself, while files are still arriving) is changing
            if changing := busy(entry):
                log(f"{changing.relative_to(INBOX)}: still being written, will retry")
                continue

            try:
                for path in [entry] if entry.is_file() else documents_in(entry):
                    # Uploading a folder takes a while, so recheck each file in case
                    # it arrived or changed since the folder was checked
                    if path != entry and not is_settled(path):
                        log(f"{path.relative_to(INBOX)}: still being written, will retry")
                        continue
                    if not process(client, path):
                        status = 1
            except Unreachable as e:
                log(f"{e}; will retry")
                return 1

            # Trash the folder once every document in it has been uploaded or moved
            # aside, unless something (say, a copy's hidden temp file, which may be
            # closed between writes or before its rename) is still being written
            if (
                entry.is_dir()
                and not documents_in(entry)
                and all(is_quiet(p) for p in entry.rglob("*"))
            ):
                subprocess.run(["/usr/bin/trash", str(entry)], check=True)
                log(f"{entry.name}: folder emptied, moved to the Trash")

    return status


if __name__ == "__main__":
    sys.exit(main())
