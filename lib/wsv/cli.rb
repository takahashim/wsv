# frozen_string_literal: true

require "optparse"
require "pathname"

module Wsv
  class CLI
    DEFAULT_HOST = "127.0.0.1"
    DEFAULT_PORT = 8000

    attr_reader :argv

    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def run
      options = parse_options(argv)
      return 0 if options[:handled]

      root = resolve_root(options[:directory])
      tls = resolve_tls(options)
      server = Server.new(
        host: options[:host], port: options[:port], root: root,
        out: @out, err: @err, tls: tls, spa: options[:spa] || false
      )
      server.start
      0
    rescue OptionParser::ParseError, ArgumentError => e
      @err.puts "wsv: #{e.message}"
      @err.puts "Try `wsv --help` for usage."
      1
    rescue SystemCallError => e
      @err.puts "wsv: #{e.message}"
      1
    end

    def parse_options(args) # rubocop:disable Metrics/AbcSize
      options = {
        host: DEFAULT_HOST,
        port: DEFAULT_PORT,
        directory: Dir.pwd
      }

      parser = OptionParser.new do |opts| # rubocop:disable Metrics/BlockLength
        opts.banner = "Usage: wsv [options] [directory]"

        opts.on("-h", "--host HOST", "Bind host (default: #{DEFAULT_HOST})") do |host|
          options[:host] = host
        end

        opts.on("-p", "--port PORT", Integer, "Bind port (default: #{DEFAULT_PORT})") do |port|
          options[:port] = validate_port(port)
        end

        opts.on("--tls", "Enable HTTPS (uses ~/.config/wsv/{cert,key}.pem if both present, else self-signed)") do
          options[:tls] = true
        end

        opts.on("--cert PATH", "TLS certificate file (PEM); implies --tls") do |path|
          options[:cert] = path
        end

        opts.on("--key PATH", "TLS private key file (PEM); implies --tls") do |path|
          options[:key] = path
        end

        opts.on("--spa", "Single-page-app mode: fall back to root index.html on 404") do
          options[:spa] = true
        end

        opts.on("--help", "Show help") do
          @out.puts opts
          options[:handled] = true
        end

        opts.on("--version", "Show version") do
          @out.puts Wsv::VERSION
          options[:handled] = true
        end
      end

      parser.parse!(args)
      raise ArgumentError, "too many directories" if args.length > 1

      options[:directory] = args.first if args.first
      options
    end

    private

    def resolve_root(directory)
      path = Pathname.new(directory).expand_path
      raise ArgumentError, "directory does not exist: #{directory}" unless path.exist?
      raise ArgumentError, "not a directory: #{directory}" unless path.directory?

      path.realpath.to_s
    end

    def validate_port(port)
      raise ArgumentError, "port must be between 1 and 65535" unless port.between?(1, 65_535)

      port
    end

    def resolve_tls(options)
      return nil unless options[:tls] || options[:cert] || options[:key]

      TlsContext::Resolver.resolve(cert_path: options[:cert], key_path: options[:key])
    rescue OpenSSL::OpenSSLError => e
      raise ArgumentError, "TLS configuration error: #{e.message}"
    end
  end
end
