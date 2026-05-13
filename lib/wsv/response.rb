# frozen_string_literal: true

require_relative "status"
require_relative "version"
require_relative "response/string_body"
require_relative "response/file_body"
require_relative "response/sse_body"
require_relative "response/text_builder"
require_relative "response/file_builder"
require_relative "response/sse_builder"

module Wsv
  class Response
    SERVER_NAME = "wsv/#{Wsv::VERSION}".freeze

    INVALID_HEADER_NAME = /[\s:]/
    INVALID_HEADER_VALUE = /[\r\n]/

    attr_reader :status, :headers

    def initialize(status:, headers: {}, body: "")
      validate_headers(headers)
      @status = status
      @headers = headers
      @body = body.is_a?(String) ? StringBody.new(body) : body
    end

    def body
      @body.to_s
    end

    def bytesize
      @body.bytesize
    end

    def reason
      Status.reason(status)
    end

    # Returns a new Response with `extra` merged into the headers, sharing the
    # same body object so streaming (FileBody) is preserved.
    def with_headers(extra)
      self.class.new(status: @status, headers: @headers.merge(extra), body: @body)
    end

    def write_to(io)
      io.write "HTTP/1.1 #{status} #{reason}\r\n"
      io.write "Server: #{SERVER_NAME}\r\n"
      io.write "Connection: close\r\n"
      unless headers.any? { |name, _value| name.to_s.casecmp?("X-Content-Type-Options") }
        io.write "X-Content-Type-Options: nosniff\r\n"
      end
      headers.each { |name, value| io.write "#{name}: #{value}\r\n" }
      io.write "\r\n"
      @body.write_to(io)
    end

    def self.text(status, **)
      TextBuilder.new(status, **).build
    end

    def self.file(path, **)
      FileBuilder.new(path, **).build
    end

    def self.redirect(location, head: false)
      TextBuilder.new(301, head: head, headers: { "Location" => location }).build
    end

    def self.not_modified
      new(status: 304, headers: { "Cache-Control" => "no-cache" }, body: "")
    end

    def self.range_not_satisfiable(file_size, head: false)
      TextBuilder.new(416, head: head, headers: { "Content-Range" => "bytes */#{file_size}" }).build
    end

    # Build a Server-Sent Events response. The block receives the client
    # socket and writes (and flushes) SSE frames until it returns.
    def self.sse(status: 200, headers: {}, &producer)
      SseBuilder.new(status: status, headers: headers, &producer).build
    end

    private

    def validate_headers(headers)
      headers.each do |name, value|
        raise ArgumentError, "invalid header name: #{name.inspect}" if name.to_s.match?(INVALID_HEADER_NAME)
        raise ArgumentError, "invalid header value: #{value.inspect}" if value.to_s.match?(INVALID_HEADER_VALUE)
      end
    end
  end
end
