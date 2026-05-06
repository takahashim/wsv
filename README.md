# wsv

`wsv` is a minimal static web server for local previews.

It has no runtime dependencies outside Ruby's standard library. Run `wsv` in a directory and it serves that directory over HTTP.

## Installation

```sh
gem install wsv
```

For local development:

```sh
gem build wsv.gemspec
gem install ./wsv-0.1.0.gem
```

## Usage

```sh
wsv [options] [directory]
```

Examples:

```sh
wsv
wsv public
wsv -h 0.0.0.0 -p 3000 ./dist
```

Options:

```text
-h, --host HOST    Bind host (default: 127.0.0.1)
-p, --port PORT    Bind port (default: 8000)
    --help         Show help
    --version      Show version
```

## Behavior

- Serves files from the selected directory.
- Serves `index.html` for directories that contain it.
- Does not render directory listings.
- Supports `GET` and `HEAD`.
- Rejects paths that resolve outside the served directory.
- Sends `Cache-Control: no-cache` for local development.

## Security model

`wsv` is intended for **local development previews, not for production or internet-facing use**.
Within that scope it tries to behave defensively:

### What `wsv` protects against

- Path traversal — `..`, absolute paths, and URL-encoded forms (`%2e%2e`) are
  resolved and rejected if they escape the served directory.
- Symlink-based escape — symlinks pointing outside the served directory are
  rejected (403). Symlinks that resolve inside the directory are followed.
- Symlink-to-dotfile bypass — even if a non-dotfile name is requested, the
  resolved real path is checked again so an internal symlink cannot smuggle
  access to `.git/`, `.env`, etc.
- Dotfile exposure — any path segment beginning with `.` is rejected (403),
  whether at the URL layer or after symlinks resolve.
- Unintended LAN exposure — the default bind is `127.0.0.1`. Passing
  `--host 0.0.0.0` (or any non-loopback address) prints a `WARNING` to
  stderr so the choice is explicit.
- Resource exhaustion from oversized requests — request line, header line,
  total header bytes, and header count are bounded; offending clients receive
  `414` or `431` and are disconnected.
- Slow / idle clients — each request has a per-request read deadline
  (default 10s, configurable). Stalled connections receive `408`.
- Header injection — CR/LF in response header values is rejected at
  construction time, so user-derived strings cannot inject extra headers.
- Single-client monopolisation — connections are handled by a thread pool
  capped at `max_connections` (default 8). Excess clients receive `503`.
- Transient `accept(2)` errors — per-connection failures (`ECONNABORTED`,
  `EMFILE`, etc.) are logged and skipped instead of killing the server.

### What `wsv` does NOT do

- Authentication, authorization, or rate limiting.
- TLS / HTTPS.
- Range requests, conditional `GET`, or HTTP keep-alive.
- Production-grade DoS resistance under hostile network load.
- Protect a directory you should not be sharing in the first place. The
  bound is the directory you pass on the command line; if it contains
  secrets, do not run `wsv` against it.

If you need any of the above, use a real production server.

## License

MIT
