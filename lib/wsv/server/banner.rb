# frozen_string_literal: true

require_relative "url_host"

module Wsv
  class Server
    # Renders the startup announcement (the "Serving / Bind / Local / Stop"
    # block plus warnings about non-loopback binds and self-signed certs).
    class Banner
      def initialize(host:, port:, root:, out:, err:, tls:)
        @host = host
        @port = port
        @root = root
        @out = out
        @err = err
        @tls = tls
      end

      def emit
        @out.puts "Serving: #{@root}"
        @out.puts "Bind:    #{url_for(@host)}"
        @out.puts "Local:   #{url_for('127.0.0.1')}" unless localhost?(@host)
        @out.puts "Stop:    Ctrl-C"
        warn_public_bind unless localhost?(@host)
        warn_ephemeral_cert if @tls&.ephemeral?
      end

      private

      def warn_public_bind
        @err.puts "WARNING: binding to #{@host} exposes #{@root} on your network."
        @err.puts "         Pass --host 127.0.0.1 (or omit --host) for local-only access."
      end

      def warn_ephemeral_cert
        @err.puts "WARNING: serving with a self-signed certificate. Browsers will"
        @err.puts "         show a security warning. Pass --cert / --key for a real cert."
      end

      def url_for(display_host)
        "#{scheme}://#{UrlHost.format(display_host)}:#{@port}/"
      end

      def scheme
        @tls ? "https" : "http"
      end

      def localhost?(display_host)
        ["127.0.0.1", "localhost", "::1"].include?(display_host)
      end
    end
  end
end
