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

## License

MIT
