# frozen_string_literal: true

module Wsv
  class Request
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
      request_line = io.gets
      return :empty unless request_line

      method, target, version = request_line.split(/\s+/, 3)
      version = version&.strip
      return :malformed unless method && target && version&.start_with?("HTTP/")

      headers = read_headers(io)
      new(method: method, target: target, version: version, headers: headers)
    end

    def self.read_headers(io)
      headers = {}
      while (line = io.gets)
        line = line.delete_suffix("\r\n").delete_suffix("\n")
        break if line.empty?

        name, value = line.split(":", 2)
        headers[name.downcase] = value.strip if name && value
      end
      headers
    end
    private_class_method :read_headers
  end
end
