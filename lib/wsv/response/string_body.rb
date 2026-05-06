# frozen_string_literal: true

module Wsv
  class Response
    class StringBody
      def initialize(string)
        @string = string
      end

      def to_s
        @string
      end

      def bytesize
        @string.bytesize
      end

      def write_to(io)
        io.write(@string) unless @string.empty?
      end
    end
  end
end
