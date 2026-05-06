# frozen_string_literal: true

require_relative "path_resolver"
require_relative "response"

module Wsv
  class App
    ALLOWED_METHODS = %w[GET HEAD].freeze

    def initialize(root)
      @resolver = PathResolver.new(root)
    end

    def call(request)
      head = request.head?

      unless ALLOWED_METHODS.include?(request.method)
        return Response.text(405, headers: { "Allow" => "GET, HEAD" }, head: head)
      end

      raw_path, query = request.target.split("?", 2)
      result = @resolver.resolve(raw_path)

      return Response.text(result.status, head: head) if result.error?
      return Response.redirect(redirect_location(raw_path, query), head: head) if result.redirect?

      Response.file(result.file, head: head)
    end

    private

    def redirect_location(raw_path, query)
      location = raw_path.end_with?("/") ? raw_path : "#{raw_path}/"
      location += "?#{query}" if query && !query.empty?
      location
    end
  end
end
