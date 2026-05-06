# frozen_string_literal: true

module Wsv
  class Request
    REQUEST_LINE_LIMIT = 8192
    HEADER_LINE_LIMIT = 8192
    HEADER_COUNT_LIMIT = 100
    HEADER_TOTAL_LIMIT = 16384

    class TooLarge < StandardError
      attr_reader :status_code

      def initialize(status_code)
        super("request exceeded size limit (#{status_code})")
        @status_code = status_code
      end
    end

    attr_reader :method, :target, :version, :headers

    def initialize(method:, target:, version:, headers:)
      @method = method
      @target = target
      @version = version
      @headers = headers
    end

    def head?
      method == "HEAD"
    end

    def self.parse(io)
      line = io.gets(REQUEST_LINE_LIMIT)
      return :empty unless line
      raise TooLarge, 414 if line.bytesize >= REQUEST_LINE_LIMIT && !line.end_with?("\n")

      method, target, version = line.split(/\s+/, 3)
      version = version&.strip
      return :malformed unless method && target && version&.start_with?("HTTP/")

      headers = read_headers(io)
      new(method: method, target: target, version: version, headers: headers)
    end

    def self.read_headers(io)
      headers = {}
      total = 0
      count = 0
      while (line = io.gets(HEADER_LINE_LIMIT))
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
    private_class_method :read_headers
  end
end
