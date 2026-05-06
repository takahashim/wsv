# frozen_string_literal: true

module Wsv
  module Status
    REASONS = {
      200 => "OK",
      301 => "Moved Permanently",
      400 => "Bad Request",
      403 => "Forbidden",
      404 => "Not Found",
      405 => "Method Not Allowed",
      408 => "Request Timeout",
      414 => "URI Too Long",
      431 => "Request Header Fields Too Large"
    }.freeze

    def self.reason(code)
      REASONS.fetch(code)
    end
  end
end
