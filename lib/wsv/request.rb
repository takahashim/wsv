# frozen_string_literal: true

require_relative "request/too_large"
require_relative "request/parser"

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
      Parser.new(io).parse
    end
  end
end
