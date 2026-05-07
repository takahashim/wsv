# frozen_string_literal: true

require "rbconfig"
require_relative "url_host"

module Wsv
  class Server
    # Launches the OS default browser at the served URL when `--open` is set.
    # Best-effort: unsupported platforms or spawn failures are logged but
    # never abort the server.
    class BrowserLauncher
      def initialize(host:, port:, tls:, err:)
        @host = host
        @port = port
        @tls = tls
        @err = err
      end

      def launch
        command = platform_command
        unless command
          @err.puts "wsv: --open is not supported on this platform; skipping."
          return
        end

        pid = Process.spawn(*command, url, in: :close, out: File::NULL, err: File::NULL)
        Process.detach(pid)
      rescue StandardError => e
        @err.puts "wsv: failed to open browser: #{e.message}"
      end

      private

      def url
        scheme = @tls ? "https" : "http"
        "#{scheme}://#{UrlHost.format(display_host)}:#{@port}/"
      end

      def display_host
        # Wildcard binds aren't reachable; redirect to the matching loopback.
        case @host
        when "0.0.0.0" then "127.0.0.1"
        when "::" then "::1"
        else @host
        end
      end

      def platform_command
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then ["open"]
        when /linux|bsd/ then ["xdg-open"]
        when /mswin|mingw|cygwin/ then ["cmd.exe", "/c", "start", ""]
        end
      end
    end
  end
end
