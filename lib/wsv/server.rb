# frozen_string_literal: true

require "socket"
require_relative "app"
require_relative "request"
require_relative "response"

module Wsv
  class Server
    DEFAULT_READ_TIMEOUT = 10
    DEFAULT_MAX_CONNECTIONS = 8
    DRAIN_TIMEOUT = 5

    attr_reader :host, :port, :root

    def initialize(
      host:,
      port:,
      root:,
      out: $stdout,
      err: $stderr,
      read_timeout: DEFAULT_READ_TIMEOUT,
      max_connections: DEFAULT_MAX_CONNECTIONS
    )
      @host = host
      @port = port
      @root = File.realpath(root)
      @out = out
      @err = err
      @read_timeout = read_timeout
      @max_connections = max_connections
      @app = App.new(@root)
      @running = false
      @mutex = Mutex.new
      @active = 0
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
      deadline = Time.now + DRAIN_TIMEOUT
      loop do
        return if Time.now >= deadline

        chunk = client.read_nonblock(8192, exception: false)
        case chunk
        when nil, :wait_writable
          return
        when :wait_readable
          remaining = deadline - Time.now
          return if remaining <= 0
          return unless client.wait_readable([remaining, 0.2].min)
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
        client = nil
        begin
          client = @server.accept
        rescue IOError, Errno::EBADF
          break
        rescue StandardError => e
          @err.puts "wsv: accept error: #{e.class}: #{e.message}"
          sleep 0.05
          next
        end

        begin
          spawn_handler(client)
        rescue StandardError => e
          @err.puts "wsv: dispatch error: #{e.class}: #{e.message}"
          begin
            client.close
          rescue StandardError
            nil
          end
        end
      end
    end

    def spawn_handler(client)
      accepted = @mutex.synchronize do
        next false if @active >= @max_connections

        @active += 1
        true
      end

      return reject(client) unless accepted

      Thread.new do
        Thread.current.report_on_exception = false
        handle(client)
      ensure
        @mutex.synchronize { @active -= 1 }
      end
    end

    def reject(client)
      write_response(client, Response.text(503))
    ensure
      graceful_close(client)
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
      @out.puts "Local:   #{url_for('127.0.0.1')}" unless localhost?(host)
      @out.puts "Stop:    Ctrl-C"
      warn_public_bind unless localhost?(host)
    end

    def warn_public_bind
      @err.puts "WARNING: binding to #{host} exposes #{root} on your network."
      @err.puts "         Pass --host 127.0.0.1 (or omit --host) for local-only access."
    end

    def url_for(display_host)
      "http://#{display_host}:#{port}/"
    end

    def localhost?(display_host)
      ["127.0.0.1", "localhost", "::1"].include?(display_host)
    end
  end
end
