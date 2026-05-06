# frozen_string_literal: true

require_relative "request/parser"

module Wsv
  class Request
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
      Parser.new(io).parse
    end
  end
end
