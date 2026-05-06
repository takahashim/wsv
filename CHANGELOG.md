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

## 0.1.0

- Initial release.
- Requests to dotfiles and dot-directories (e.g. `/.git/...`, `/.env`) return 403.
