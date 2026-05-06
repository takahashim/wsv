# frozen_string_literal: true

require "time"
require_relative "mime_types"
require_relative "version"

module Wsv
  class Response
    SERVER_NAME = "wsv/#{Wsv::VERSION}"

    REASONS = {
      200 => "OK",
      301 => "Moved Permanently",
      400 => "Bad Request",
      403 => "Forbidden",
      404 => "Not Found",
      405 => "Method Not Allowed"
    }.freeze

    attr_reader :status, :headers, :body

    def initialize(status:, headers: {}, body: "")
      @status = status
      @headers = headers
      @body = body
    end

    def reason
      REASONS.fetch(status)
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
      body = "#{status} #{REASONS.fetch(status)}\n"
      base = {
        "Content-Type" => "text/plain; charset=utf-8",
        "Content-Length" => body.bytesize.to_s,
        "Cache-Control" => "no-cache"
      }
      new(status: status, headers: base.merge(headers), body: head ? "" : body)
    end

    def self.file(path, head: false)
      new(
        status: 200,
        headers: {
          "Content-Type" => MimeTypes.for_file(path),
          "Content-Length" => File.size(path).to_s,
          "Last-Modified" => File.mtime(path).httpdate,
          "Cache-Control" => "no-cache"
        },
        body: head ? "" : File.binread(path)
      )
    end

    def self.redirect(location, head: false)
      text(301, headers: {"Location" => location}, head: head)
    end
  end
end
