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
      server = Server.new(host: options[:host], port: options[:port], root: root, out: @out, err: @err)
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

    def parse_options(args)
      options = {
        host: DEFAULT_HOST,
        port: DEFAULT_PORT,
        directory: Dir.pwd
      }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: wsv [options] [directory]"

        opts.on("-h", "--host HOST", "Bind host (default: #{DEFAULT_HOST})") do |host|
          options[:host] = host
        end

        opts.on("-p", "--port PORT", Integer, "Bind port (default: #{DEFAULT_PORT})") do |port|
          options[:port] = validate_port(port)
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
  end
end
