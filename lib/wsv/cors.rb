# frozen_string_literal: true

require_relative "response"

module Wsv
  class Cors
    ALLOW_ORIGIN = "*"
    ALLOW_METHODS = %w[GET HEAD OPTIONS].freeze
    MAX_AGE = "86400"

    def allow_methods
      ALLOW_METHODS
    end

    def preflight(request)
      headers = {
        "Access-Control-Allow-Methods" => ALLOW_METHODS.join(", "),
        "Access-Control-Max-Age" => MAX_AGE
      }
      requested = request.headers["access-control-request-headers"]
      headers["Access-Control-Allow-Headers"] = requested if requested
      Response.new(status: 204, headers: headers)
    end

    def overlay(response)
      response.with_headers(
        "Access-Control-Allow-Origin" => ALLOW_ORIGIN,
        "Vary" => "Origin"
      )
    end
  end
end
