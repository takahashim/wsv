# frozen_string_literal: true

module Wsv
  class Response
    class TextBuilder
      def initialize(status, head: false, headers: {})
        @status = status
        @head = head
        @extra_headers = headers
      end

      def build
        Response.new(status: @status, headers: response_headers, body: response_body)
      end

      private

      def response_body
        @head ? "" : message
      end

      def message
        @message ||= "#{@status} #{Status.reason(@status)}\n"
      end

      def response_headers
        {
          "Content-Type" => "text/plain; charset=utf-8",
          "Content-Length" => message.bytesize.to_s,
          "Cache-Control" => "no-cache"
        }.merge(@extra_headers)
      end
    end
  end
end
