# Changelog

## 0.10.0

- TLS / HTTPS support via Ruby's built-in `openssl` (no extra gem dependency).
  - `--tls` enables HTTPS. Without `--cert / --key`, wsv looks for
    `~/.config/wsv/cert.pem` and `~/.config/wsv/key.pem` (respecting
    `XDG_CONFIG_HOME`); if neither is present, an ephemeral self-signed
    certificate is generated in memory and a warning is printed.
  - `--cert PATH --key PATH` uses a user-supplied PEM cert / key pair and
    implies `--tls`. Specifying only one of the two is an error.
  - `~/.config/wsv/` (or `$XDG_CONFIG_HOME/wsv/`) is the recommended location
    for mkcert-issued certificates: `mkcert -cert-file ~/.config/wsv/cert.pem
    -key-file ~/.config/wsv/key.pem localhost 127.0.0.1 ::1`.
  - The HTTP scheme in the startup banner switches to `https://` when TLS is
    enabled.
  - The TLS handshake honours the per-request read deadline, so slow-handshake
    clients cannot hold a worker beyond the configured timeout.

## 0.9.0

- Normalize the redirect `Location` to an origin-form path. Previously, an
  absolute-form request target such as `GET http://example.test/docs HTTP/1.1`
  produced `Location: http://example.test/docs/`; now it always emits
  `Location: /docs/`.
- Reject control characters (C0 0x00-0x1F and 0x7F DEL) in the
  decoded request path with `400`. RFC 3986 disallows them in URL paths;
  this prevents NUL-byte `ArgumentError` from leaking out of
  `Wsv::PathResolver` and provides defence-in-depth against CR/LF
  smuggling alongside the existing response-header validation.
- Document the local-FS TOCTOU limitation in README's security model:
  another local process with write access to the served directory can swap
  files between path resolution and `File.open`. This is acknowledged as
  out-of-scope for a development tool.
- Decrement the in-flight connection counter when `Thread.new` itself raises
  `ThreadError` (e.g. OS thread limit reached). The dispatch returns `503`
  for the rejected client and the server continues accepting subsequent
  connections instead of permanently leaking a slot.
- Stream file responses through `IO.copy_stream` instead of buffering the
  whole file in memory. Reduces RSS for large files and uses `sendfile(2)`
  on Linux when available. `Response#body` still materializes to a String
  for callers; the change is internal to the wire path.
- Support `Range` requests for static files (`206 Partial Content` with
  `Content-Range`). Open-ended (`bytes=N-`), suffix (`bytes=-N`), and
  bounded (`bytes=N-M`) forms are supported. Unsatisfiable ranges return
  `416`; invalid syntax falls through to a normal `200`.
- Honour `If-Modified-Since` and return `304 Not Modified` when the file's
  mtime (truncated to seconds) is at or before the supplied date.
- Advertise `Accept-Ranges: bytes` on `200` and `206` file responses.
- Document the public API contract in README: the CLI is the SemVer
  surface. Ruby classes under `lib/wsv/` are implementation details.

## 0.8.0

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
- Add RuboCop with `rubocop-minitest` / `rubocop-rake` plugins. `rake` now
  runs both `test` and `rubocop`.
- Add GitHub Actions CI: tests on Ruby 3.2 / 3.3 / 3.4 plus a separate
  RuboCop job.
- Document the security model in README (what `wsv` protects against and
  what is explicitly out of scope).

## 0.1.0

- Initial release.
- Requests to dotfiles and dot-directories (e.g. `/.git/...`, `/.env`) return 403.
