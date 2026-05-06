# frozen_string_literal: true

require "socket"
require_relative "app"
require_relative "request"
require_relative "response"

module Wsv
  class Server
    DEFAULT_READ_TIMEOUT = 10

    attr_reader :host, :port, :root

    def initialize(host:, port:, root:, out: $stdout, err: $stderr, read_timeout: DEFAULT_READ_TIMEOUT)
      @host = host
      @port = port
      @root = File.realpath(root)
      @out = out
      @err = err
      @read_timeout = read_timeout
      @app = App.new(@root)
      @running = false
    end

    def start
      @server = TCPServer.new(host, port)
      @running = true
      log_startup
      trap_signals
      accept_loop
    ensure
      close
    end

    def stop
      @running = false
      close
    end

    def handle(client)
      reader = DeadlineReader.new(client, Time.now + @read_timeout)
      request = Request.parse(reader)
      case request
      when :empty
        nil
      when :malformed
        write_response(client, Response.text(400))
      else
        write_response(client, @app.call(request))
      end
    rescue Request::TooLarge => e
      write_response(client, Response.text(e.status_code))
    rescue IO::TimeoutError
      write_response(client, Response.text(408))
    rescue StandardError => e
      @err.puts "wsv: #{e.class}: #{e.message}"
      write_response(client, Response.text(400))
    ensure
      graceful_close(client)
    end

    private

    def write_response(client, response)
      return if client.closed?

      response.write_to(client)
    rescue Errno::EPIPE, Errno::ECONNRESET, IOError
      nil
    end

    def graceful_close(client)
      return if client.closed?

      drain_recv(client)
    rescue StandardError
      nil
    ensure
      begin
        client.close unless client.closed?
      rescue StandardError
        nil
      end
    end

    def drain_recv(client)
      loop do
        chunk = client.read_nonblock(8192, exception: false)
        case chunk
        when nil, :wait_writable
          break
        when :wait_readable
          break unless IO.select([client], nil, nil, 0.2)
        end
      end
    end

    class DeadlineReader
      def initialize(io, deadline)
        @io = io
        @deadline = deadline
      end

      def gets(limit)
        remaining = @deadline - Time.now
        raise IO::TimeoutError if remaining <= 0

        @io.timeout = remaining
        @io.gets(limit)
      end
    end

    def accept_loop
      while @running
        begin
          client = @server.accept
          handle(client)
        rescue IOError, Errno::EBADF
          break unless @running
        end
      end
    end

    def close
      @server&.close unless @server&.closed?
    end

    def trap_signals
      %w[INT TERM].each do |signal|
        Signal.trap(signal) do
          @out.puts "\nStopping wsv."
          stop
        end
      end
    rescue ArgumentError
      nil
    end

    def log_startup
      @out.puts "Serving: #{root}"
      @out.puts "Bind:    #{url_for(host)}"
      @out.puts "Local:   #{url_for("127.0.0.1")}" unless localhost?(host)
      @out.puts "Stop:    Ctrl-C"
    end

    def url_for(display_host)
      "http://#{display_host}:#{port}/"
    end

    def localhost?(display_host)
      display_host == "127.0.0.1" || display_host == "localhost" || display_host == "::1"
    end
  end
end
