# frozen_string_literal: true

require "openssl"
require "socket"
require_relative "app"
require_relative "cors"
require_relative "server/banner"
require_relative "server/browser_launcher"
require_relative "server/connection"
require_relative "server/connection_throttle"

module Wsv
  class Server
    DEFAULT_READ_TIMEOUT = 10
    DEFAULT_MAX_CONNECTIONS = 8

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
      open: false,
      cors: false
    )
      @host = host
      @port = port
      @root = File.realpath(root)
      @out = out
      @err = err
      @read_timeout = read_timeout
      @tls = tls
      @ssl_context = tls&.to_ssl_context
      @open = open
      @cors = Cors.new if cors
      @app = App.new(@root, spa: spa, cors: @cors)
      @throttle = ConnectionThrottle.new(max: max_connections, err: err)
      @running = false
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

    private

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
      accepted = @throttle.try_spawn do
        Connection.new(maybe_wrap_tls(client), err: @err, cors: @cors).serve(@app, read_timeout: @read_timeout)
      end
      spawn_rejection(client) unless accepted
    end

    # Reject in a separate thread so a slow client cannot block accept_loop
    # via Connection#graceful_close (up to Connection::DRAIN_TIMEOUT seconds).
    # In TLS mode `client` is the raw TCPSocket before any handshake; writing
    # a plaintext 503 would corrupt the TLS handshake the client is about to
    # start, so suppress the reply in that case.
    def spawn_rejection(client)
      reply = !@ssl_context
      Thread.new do
        Thread.current.report_on_exception = false
        Connection.new(client, err: @err, cors: @cors).reject(reply: reply)
      end
    rescue ThreadError
      Connection.new(client, err: @err, cors: @cors).reject(reply: reply)
    end

    def maybe_wrap_tls(client)
      return client unless @ssl_context

      client.timeout = @read_timeout
      ssl = OpenSSL::SSL::SSLSocket.new(client, @ssl_context)
      ssl.sync_close = true
      ssl.accept
      ssl
    rescue StandardError
      # If wrapping or the handshake failed, `serve` is never called and
      # its ensure does not get a chance to close the underlying socket.
      # Close it here so we do not leak a TCPSocket per failed handshake.
      begin
        client.close
      rescue StandardError
        nil
      end
      raise
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
