# frozen_string_literal: true

require_relative "response"

module Wsv
  class Cors
    ALLOW_ORIGIN = "*"
    ALLOW_METHODS = "GET, HEAD, OPTIONS"
    MAX_AGE = "86400"

    def preflight(request)
      headers = {
        "Access-Control-Allow-Origin" => ALLOW_ORIGIN,
        "Access-Control-Allow-Methods" => ALLOW_METHODS,
        "Access-Control-Max-Age" => MAX_AGE,
        "Vary" => "Origin"
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
