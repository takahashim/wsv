# frozen_string_literal: true

require "openssl"
require "socket"
require_relative "app"
require_relative "request"
require_relative "response"
require_relative "server/banner"
require_relative "server/browser_launcher"
require_relative "server/deadline_reader"

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
      max_connections: DEFAULT_MAX_CONNECTIONS,
      tls: nil,
      spa: false,
      open: false
    )
      @host = host
      @port = port
      @root = File.realpath(root)
      @out = out
      @err = err
      @read_timeout = read_timeout
      @max_connections = max_connections
      @tls = tls
      @ssl_context = tls&.to_ssl_context
      @open = open
      @app = App.new(@root, spa: spa)
      @running = false
      @mutex = Mutex.new
      @active = 0
    end

    def start
      @server = TCPServer.new(host, port)
      @running = true
      log_startup
      trap_signals
      open_in_browser if @open
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
      # Treat unmapped failures as connection-scoped and close with 400 rather
      # than letting one bad request path bring down the server.
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
          # nil = EOF. :wait_writable can come back from SSLSocket during a
          # renegotiation (read needs an underlying write). Either way,
          # there's nothing more we can usefully drain right now.
          return
        when :wait_readable
          remaining = deadline - Time.now
          return if remaining <= 0
          return unless client.wait_readable([remaining, 0.2].min)
        end
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

      return spawn_rejection(client) unless accepted

      begin
        Thread.new do
          Thread.current.report_on_exception = false
          handle(maybe_wrap_tls(client))
        ensure
          @mutex.synchronize { @active -= 1 }
        end
      rescue ThreadError => e
        @err.puts "wsv: thread error: #{e.message}"
        @mutex.synchronize { @active -= 1 }
        spawn_rejection(client)
      end
    end

    # Reject in a separate thread so a slow client cannot block accept_loop
    # via graceful_close's drain_recv (up to DRAIN_TIMEOUT seconds).
    def spawn_rejection(client)
      Thread.new do
        Thread.current.report_on_exception = false
        reject(client)
      end
    rescue ThreadError
      reject(client)
    end

    def maybe_wrap_tls(client)
      return client unless @ssl_context

      client.timeout = @read_timeout
      ssl = OpenSSL::SSL::SSLSocket.new(client, @ssl_context)
      ssl.sync_close = true
      ssl.accept
      ssl
    rescue StandardError
      # If wrapping or the handshake failed, `handle` is never called and
      # its ensure does not get a chance to close the underlying socket.
      # Close it here so we do not leak a TCPSocket per failed handshake.
      begin
        client.close
      rescue StandardError
        nil
      end
      raise
    end

    def reject(client)
      # In TLS mode `client` is the raw TCPSocket before any handshake.
      # Writing a plaintext 503 over it would corrupt the TLS handshake
      # the client is about to start, so just close in that case.
      write_response(client, Response.text(503)) unless @ssl_context
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
      # Signal.trap raises ArgumentError when called from a context that
      # cannot install signal handlers (e.g. embedded in a non-main thread,
      # which is how tests start the server). Skip silently in that case.
      nil
    end

    def log_startup
      Banner.new(host: host, port: port, root: root, out: @out, err: @err, tls: @tls).emit
    end

    def open_in_browser
      BrowserLauncher.new(host: host, port: port, tls: @tls, err: @err).launch
    end
  end
end
