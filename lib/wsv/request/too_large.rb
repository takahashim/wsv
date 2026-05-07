# frozen_string_literal: true

module Wsv
  class Request
    # Raised by Request::Parser when the incoming request line, an individual
    # header line, the total header bytes, or the header count exceeds the
    # configured limit. The status_code chooses between 414 (URI Too Long)
    # and 431 (Request Header Fields Too Large) at the call site.
    class TooLarge < StandardError
      attr_reader :status_code

      def initialize(status_code)
        super("request exceeded size limit (#{status_code})")
        @status_code = status_code
      end
    end
  end
end
