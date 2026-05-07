# frozen_string_literal: true

require "time"
require "uri"
require_relative "cors"
require_relative "path_resolver"
require_relative "range_request"
require_relative "response"

module Wsv
  class App
    ALLOWED_METHODS = %w[GET HEAD].freeze

    def initialize(root, spa: false, cors: nil)
      @resolver = PathResolver.new(root)
      @spa = spa
      @cors = cors
    end

    def call(request)
      return @cors.preflight(request) if @cors && request.method == "OPTIONS"

      build_response(request)
    end

    private

    def build_response(request)
      head = request.head?

      unless ALLOWED_METHODS.include?(request.method)
        return Response.text(405, headers: { "Allow" => allow_header }, head: head)
      end

      raw_path, query = request.target.split("?", 2)
      result = @resolver.resolve(raw_path)

      # SPA fallback: when the path resolves to 404, retry with "/" so client-side
      # routes (React Router etc.) get index.html instead of a real 404. Other
      # error statuses (403/400) are not rewritten, so dotfile / traversal blocks
      # still take effect.
      if @spa && result.error? && result.status == 404
        fallback = @resolver.resolve("/")
        result = fallback if fallback.file?
      end

      return error_response(result.status, head: head) if result.error?
      return Response.redirect(redirect_location(raw_path, query), head: head) if result.redirect?

      file_response(result.file, request, head: head)
    end

    def allow_header
      (@cors&.allow_methods || ALLOWED_METHODS).join(", ")
    end

    def error_response(status, head:)
      if status == 404
        # Custom 404 page convention: when the served root contains a `404.html`
        # file, serve it as the body of any 404 response (Content-Type: text/html).
        custom = @resolver.resolve("/404.html")
        return Response.file(custom.file, status: 404, head: head) if custom.file?
      end
      Response.text(status, head: head)
    end

    def file_response(file, request, head:)
      return Response.not_modified if not_modified?(file, request.headers["if-modified-since"])

      size = File.size(file)
      range = RangeRequest.parse(request.headers["range"], size)
      return Response.range_not_satisfiable(size, head: head) if range.unsatisfiable?
      return Response.file(file, head: head) if range.full?

      Response.file(file, head: head, range: range.bounds)
    end

    def not_modified?(file, header_value)
      return false unless header_value

      since = Time.httpdate(header_value)
      File.mtime(file).to_i <= since.to_i
    rescue ArgumentError
      false
    end

    def redirect_location(raw_path, query)
      path = URI(raw_path.to_s).path
      path = "/" if path.empty?
      location = path.end_with?("/") ? path : "#{path}/"
      location += "?#{query}" if query && !query.empty?
      location
    rescue URI::InvalidURIError
      "/"
    end
  end
end
