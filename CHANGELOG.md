# Changelog

## Unreleased

- Bound request size: 8 KiB request line, 8 KiB per header line, 16 KiB total
  headers, 100 header lines. Returns 414 / 431 when exceeded.
- Per-request read deadline (default 10s) for slow/idle clients. Returns 408
  on timeout. Configurable via `Server.new(... read_timeout:)`.
- Reject CR/LF in response header values to prevent header injection.
- Drain receive buffer before closing to deliver error responses cleanly
  instead of resetting the connection.
- Minimum Ruby version raised to 3.2 (uses `IO#timeout=`).
- Apply the dotfile filter to the resolved real path so a symlink inside the
  root cannot smuggle access to `.git/`, `.env`, etc. Symlink loops and
  permission errors now resolve to 404 cleanly.
- Concurrent connection handling: a thread is spawned per accepted client up
  to `max_connections` (default 8). Idle servers hold no worker threads.
  Connections beyond the cap receive 503 and are closed.
- Print a `WARNING` to stderr when binding to a non-loopback address so
  exposing the served directory to the network is intentional, not silent.
- Cap the post-response receive drain at 5 seconds so a malicious or stuck
  client cannot tie up a worker indefinitely while sending body bytes after
  the response has been written.
- Make the accept loop resilient to transient errors: per-connection failures
  (`ECONNABORTED`, `EMFILE`, `ENOMEM`, etc.) are logged and skipped instead of
  killing the server. A 50 ms backoff prevents tight error loops.

## 0.1.0

- Initial release.
- Requests to dotfiles and dot-directories (e.g. `/.git/...`, `/.env`) return 403.
