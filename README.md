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
    --tls          Enable HTTPS (uses ~/.config/wsv/{cert,key}.pem if both present, else self-signed)
    --cert PATH    TLS certificate file (PEM); implies --tls
    --key PATH     TLS private key file (PEM); implies --tls
    --help         Show help
    --version      Show version
```

## TLS / HTTPS

`--tls` enables HTTPS on the chosen `--port`. Three modes:

1. **Ephemeral self-signed** — `wsv --tls` with no cert configured: wsv
   generates an in-memory self-signed certificate. Browsers will show a
   security warning; click through "Advanced → Proceed" once per session.
2. **`~/.config/wsv/` auto-detection (recommended)** — if both
   `~/.config/wsv/cert.pem` and `~/.config/wsv/key.pem` exist (resolved via
   `$XDG_CONFIG_HOME` if set), `--tls` uses them. If only one of the two
   files is present, wsv refuses to start so the misconfiguration does not
   silently fall back to a self-signed certificate. Combine with
   [mkcert](https://github.com/FiloSottile/mkcert) to skip browser warnings:

   ```sh
   mkcert -install     # one-time: register a local CA in your trust stores
   mkdir -p ~/.config/wsv
   mkcert -cert-file ~/.config/wsv/cert.pem \
          -key-file  ~/.config/wsv/key.pem  \
          localhost 127.0.0.1 ::1
   chmod 600 ~/.config/wsv/key.pem
   wsv --tls           # → https://localhost:8000/ with no warning
   ```

3. **Explicit cert/key files** — `wsv --cert path/to/cert.pem --key path/to/key.pem`
   for project-specific certificates. Both flags must be provided together.

## Behavior

- Serves files from the selected directory.
- Serves `index.html` for directories that contain it.
- Does not render directory listings.
- Supports `GET` and `HEAD`.
- Supports `Range` requests (`206 Partial Content` with `Content-Range`).
- Honours `If-Modified-Since` and returns `304 Not Modified` when applicable.
- Rejects paths that resolve outside the served directory.
- Sends `Cache-Control: no-cache` so the browser revalidates each request.

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
  capped at `max_connections` (default 8). Excess clients receive `503`
  (or are closed without response in TLS mode, since writing plaintext over
  a half-handshaked TLS socket would corrupt the client's view of the
  protocol).
- Transient `accept(2)` errors — per-connection failures (`ECONNABORTED`,
  `EMFILE`, etc.) are logged and skipped instead of killing the server.

### What `wsv` does NOT do

- Authentication, authorization, or rate limiting.
- HTTP keep-alive (each response sets `Connection: close`).
- ETags / `If-None-Match`.
- Production-grade DoS resistance under hostile network load.
- Defend against TOCTOU attacks from other local processes that can write
  to the served directory. Path resolution (canonicalisation, dotfile
  checks, within-root verification) happens before each file is opened;
  another process that can swap files in the served directory between
  resolution and read could redirect a request elsewhere on the same
  machine.
- Protect a directory you should not be sharing in the first place. The
  bound is the directory you pass on the command line; if it contains
  secrets, do not run `wsv` against it.

If you need any of the above, use a real production server.

## Public API and stability

`wsv` follows [Semantic Versioning](https://semver.org/). The public API
that SemVer covers is the CLI:

- The flags listed above (`-h` / `--host`, `-p` / `--port`, `--help`,
  `--version`) and their meanings.
- The directory argument and the default behaviour when it is omitted.
- Process exit codes (`0` for success, `1` for usage / setup errors).

Within a major version, `wsv` will not silently change the default bind
host, default port, the dotfile-blocking rule, or the security posture in
ways that would surprise an existing user.

The Ruby classes inside `lib/wsv/` (`Wsv::Server`, `Wsv::App`,
`Wsv::PathResolver`, `Wsv::Request`, `Wsv::Response`, `Wsv::MimeTypes`,
`Wsv::Status`) are implementation details. They may change at any
time, including in patch releases. If you want to embed `wsv` as a
library, pin a specific version.

## License

MIT
