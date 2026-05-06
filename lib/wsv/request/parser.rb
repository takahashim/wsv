# frozen_string_literal: true

module Wsv
  class Request
    class Parser
      REQUEST_LINE_LIMIT = 8192
      HEADER_LINE_LIMIT = 8192
      HEADER_COUNT_LIMIT = 100
      HEADER_TOTAL_LIMIT = 16_384

      def initialize(io)
        @io = io
      end

      def parse
        line = @io.gets(REQUEST_LINE_LIMIT)
        return :empty unless line
        raise TooLarge, 414 if line.bytesize >= REQUEST_LINE_LIMIT && !line.end_with?("\n")

        method, target, version = line.split(/\s+/, 3)
        version = version&.strip
        return :malformed unless method && target && version&.start_with?("HTTP/")

        Request.new(method: method, target: target, version: version, headers: read_headers)
      end

      private

      def read_headers
        headers = {}
        total = 0
        count = 0
        while (line = @io.gets(HEADER_LINE_LIMIT))
          raise TooLarge, 431 if line.bytesize >= HEADER_LINE_LIMIT && !line.end_with?("\n")

          stripped = line.delete_suffix("\r\n").delete_suffix("\n").delete_suffix("\r")
          break if stripped.empty?

          count += 1
          raise TooLarge, 431 if count > HEADER_COUNT_LIMIT

          total += line.bytesize
          raise TooLarge, 431 if total > HEADER_TOTAL_LIMIT

          name, value = stripped.split(":", 2)
          headers[name.downcase] = value.strip if name && value
        end
        headers
      end
    end
  end
end
