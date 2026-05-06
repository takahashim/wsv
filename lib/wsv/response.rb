# frozen_string_literal: true

require "time"
require_relative "mime_types"
require_relative "status"
require_relative "version"

module Wsv
  class Response
    SERVER_NAME = "wsv/#{Wsv::VERSION}".freeze

    INVALID_HEADER_NAME = /[\s:]/
    INVALID_HEADER_VALUE = /[\r\n]/

    attr_reader :status, :headers, :body

    def initialize(status:, headers: {}, body: "")
      headers.each do |name, value|
        raise ArgumentError, "invalid header name: #{name.inspect}" if name.to_s.match?(INVALID_HEADER_NAME)
        raise ArgumentError, "invalid header value: #{value.inspect}" if value.to_s.match?(INVALID_HEADER_VALUE)
      end
      @status = status
      @headers = headers
      @body = body
    end

    def reason
      Status.reason(status)
    end

    def write_to(io)
      io.write "HTTP/1.1 #{status} #{reason}\r\n"
      io.write "Server: #{SERVER_NAME}\r\n"
      io.write "Connection: close\r\n"
      headers.each { |name, value| io.write "#{name}: #{value}\r\n" }
      io.write "\r\n"
      io.write body
    end

    def self.text(status, headers: {}, head: false)
      body = "#{status} #{Status.reason(status)}\n"
      base = {
        "Content-Type" => "text/plain; charset=utf-8",
        "Content-Length" => body.bytesize.to_s,
        "Cache-Control" => "no-cache"
      }
      new(status: status, headers: base.merge(headers), body: head ? "" : body)
    end

    def self.file(path, head: false, range: nil)
      size = File.size(path)
      headers = {
        "Content-Type" => MimeTypes.for_file(path),
        "Last-Modified" => File.mtime(path).httpdate,
        "Cache-Control" => "no-cache",
        "Accept-Ranges" => "bytes"
      }
      if range
        headers["Content-Length"] = range.size.to_s
        headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{size}"
        new(status: 206, headers: headers, body: head ? "" : read_range(path, range))
      else
        headers["Content-Length"] = size.to_s
        new(status: 200, headers: headers, body: head ? "" : File.binread(path))
      end
    end

    def self.read_range(path, range)
      File.open(path, "rb") do |f|
        f.seek(range.begin)
        f.read(range.size)
      end
    end
    private_class_method :read_range

    def self.not_modified
      new(status: 304, headers: { "Cache-Control" => "no-cache" }, body: "")
    end

    def self.range_not_satisfiable(file_size, head: false)
      body = "416 Range Not Satisfiable\n"
      new(
        status: 416,
        headers: {
          "Content-Type" => "text/plain; charset=utf-8",
          "Content-Length" => body.bytesize.to_s,
          "Content-Range" => "bytes */#{file_size}",
          "Cache-Control" => "no-cache"
        },
        body: head ? "" : body
      )
    end

    def self.redirect(location, head: false)
      text(301, headers: { "Location" => location }, head: head)
    end
  end
end
