# frozen_string_literal: true

module Wsv
  class Response
    class FileBody
      def initialize(path, offset: 0, length: nil)
        @path = path
        @offset = offset
        @length = length || (File.size(path) - offset)
      end

      def to_s
        File.open(@path, "rb") do |f|
          f.seek(@offset)
          f.read(@length)
        end
      end

      def bytesize
        @length
      end

      def write_to(io)
        File.open(@path, "rb") do |f|
          f.seek(@offset)
          IO.copy_stream(f, io, @length)
        end
      end
    end
  end
end
