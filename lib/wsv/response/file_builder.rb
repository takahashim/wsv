# frozen_string_literal: true

require "time"
require_relative "../mime_types"

module Wsv
  class Response
    class FileBuilder
      def initialize(path, head: false, range: nil)
        @path = path
        @head = head
        @range = range
      end

      def build
        if @range
          Response.new(status: 206, headers: range_headers, body: range_body)
        else
          Response.new(status: 200, headers: full_headers, body: full_body)
        end
      end

      private

      def size
        @size ||= File.size(@path)
      end

      def base_headers
        {
          "Content-Type" => MimeTypes.for_file(@path),
          "Last-Modified" => File.mtime(@path).httpdate,
          "Cache-Control" => "no-cache",
          "Accept-Ranges" => "bytes"
        }
      end

      def range_headers
        base_headers.merge(
          "Content-Length" => @range.size.to_s,
          "Content-Range" => "bytes #{@range.begin}-#{@range.end}/#{size}"
        )
      end

      def full_headers
        base_headers.merge("Content-Length" => size.to_s)
      end

      def range_body
        return "" if @head

        File.open(@path, "rb") do |f|
          f.seek(@range.begin)
          f.read(@range.size)
        end
      end

      def full_body
        @head ? "" : File.binread(@path)
      end
    end
  end
end
