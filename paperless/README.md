# paperless

A LaunchAgent that uploads anything dropped in `~/Inbox` to
[Paperless-ngx](https://docs.paperless-ngx.com), then moves it to the Trash.

| File                                                   | What it is                          |
| ------------------------------------------------------ | ----------------------------------- |
| `.local/bin/paperless-inbox.py`                        | The uploader, a [uv script](https://docs.astral.sh/uv/guides/scripts/) |
| `Library/LaunchAgents/net.wetzler.paperless-inbox.plist` | Runs it whenever `~/Inbox` is non-empty |

## Setup on a new Mac

Stow links both files, and the Brewfile installs `uv`, but the job also needs its
settings and loading:

1. Store the Paperless URL and API token in the keychain (each prompts for its value):

   ```sh
   security add-generic-password -s paperless-inbox -a url -w
   security add-generic-password -s paperless-inbox -a api-token -w
   ```

2. Create the inbox and load the job:

   ```sh
   mkdir -p ~/Inbox
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/net.wetzler.paperless-inbox.plist
   ```

After changing the plist, reload it with `launchctl bootout gui/$(id -u)/net.wetzler.paperless-inbox`
and then the `bootstrap` command again. Script changes take effect on the next run.

## What happens to a file

launchd (via `QueueDirectories`) keeps relaunching the script until `~/Inbox` is
empty, so every file has to leave:

- **Trash:** Paperless's task API confirmed it was consumed.
- **`~/Inbox Failed`:** Paperless rejected it (unsupported, a duplicate, consume
  error or timeout), or it was hidden or a directory. Hidden files are never
  uploaded; `.DS_Store` is just deleted.
- **Left in place, retried:** it was modified in the last 10 seconds, another app
  still has it open, it looks like a partial download, or Paperless was
  unreachable. Retries are at most every 30 seconds.

Once Paperless has acknowledged an upload, the file leaves the inbox even if
confirming it fails, so it isn't uploaded again. If the upload's response is lost
(a timeout, say), the file stays and is retried; Paperless then rejects the retry
as a duplicate, and the file lands in `~/Inbox Failed` with the existing
document's ID in the log.

The log is `~/Library/Logs/paperless-inbox.log`.

## Gotchas

- **The inbox can't be in `~/Documents`, `~/Desktop` or `~/Downloads`.** launchd's
  folder watcher can't see into privacy-protected (TCC) folders, so the job never
  fires there, even with Full Disk Access granted to `uv`.
- **Paperless must reject duplicates.** Since v3 it accepts them unless
  `PAPERLESS_CONSUMER_DELETE_DUPLICATES=true` is set on the server.
- **The proxy in front of Paperless must let `/api/` through** with just the token.

The keychain settings can be overridden with `PAPERLESS_URL` and `PAPERLESS_TOKEN`,
and the folders with `PAPERLESS_INBOX` and `PAPERLESS_FAILED_DIR`. If you change the
inbox, also change `QueueDirectories` in the plist, since that's the folder launchd
actually watches.
