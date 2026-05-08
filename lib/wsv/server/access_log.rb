# frozen_string_literal: true

module Wsv
  class Server
    # Emits one line per served request in Common Log Format. Concurrent
    # Connection threads share a single AccessLog instance, so writes are
    # serialized through a mutex to avoid interleaved bytes on @out.
    class AccessLog
      def initialize(out:)
        @out = out
        @mutex = Mutex.new
      end

      def record(remote_addr:, request:, status:, bytes:)
        line = format_line(remote_addr, request, status, bytes)
        @mutex.synchronize { @out.puts(line) }
      rescue IOError
        nil
      end

      private

      def format_line(remote_addr, request, status, bytes)
        host = remote_addr || "-"
        timestamp = Time.now.strftime("[%d/%b/%Y:%H:%M:%S %z]")
        request_line = format_request_line(request)
        size = bytes.positive? ? bytes.to_s : "-"
        %(#{host} - - #{timestamp} "#{request_line}" #{status} #{size})
      end

      def format_request_line(request)
        return "-" unless request

        "#{sanitize(request.method)} #{sanitize(request.target)} #{sanitize(request.version)}"
      end

      # Replace control chars, quote, and backslash so a hostile request line
      # cannot inject CR/LF or escape the surrounding quotes in the log line.
      def sanitize(str)
        str.to_s.gsub(/[\x00-\x1f\x7f"\\]/) { |c| format('\\x%02x', c.ord) }
      end
    end

    class NullAccessLog
      def record(**); end
    end
  end
end
