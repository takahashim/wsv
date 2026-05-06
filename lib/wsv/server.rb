# frozen_string_literal: true

require "socket"
require_relative "app"
require_relative "request"
require_relative "response"

module Wsv
  class Server
    attr_reader :host, :port, :root

    def initialize(host:, port:, root:, out: $stdout, err: $stderr)
      @host = host
      @port = port
      @root = File.realpath(root)
      @out = out
      @err = err
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
      request = Request.parse(client)
      case request
      when :empty
        nil
      when :malformed
        Response.text(400).write_to(client)
      else
        @app.call(request).write_to(client)
      end
    rescue StandardError => e
      @err.puts "wsv: #{e.class}: #{e.message}"
      Response.text(400).write_to(client) unless client.closed?
    ensure
      client.close unless client.closed?
    end

    private

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
