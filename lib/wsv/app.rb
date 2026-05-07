# frozen_string_literal: true

require "time"
require "uri"
require_relative "cors"
require_relative "path_resolver"
require_relative "response"

module Wsv
  class App
    ALLOWED_METHODS = %w[GET HEAD].freeze
    RANGE_PATTERN = /\Abytes=(\d+)?-(\d+)?\z/

    def initialize(root, spa: false, cors: false)
      @resolver = PathResolver.new(root)
      @spa = spa
      @cors = Cors.new if cors
    end

    def call(request)
      return @cors.preflight(request) if @cors && request.method == "OPTIONS"

      response = build_response(request)
      @cors ? @cors.overlay(response) : response
    end

    private

    def build_response(request)
      head = request.head?

      unless ALLOWED_METHODS.include?(request.method)
        return Response.text(405, headers: { "Allow" => allow_methods }, head: head)
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

    def allow_methods
      @cors ? Cors::ALLOW_METHODS : "GET, HEAD"
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
      range = parse_range(request.headers["range"], size)
      case range
      when :unsatisfiable
        Response.range_not_satisfiable(size, head: head)
      when nil
        Response.file(file, head: head)
      else
        Response.file(file, head: head, range: range)
      end
    end

    def not_modified?(file, header_value)
      return false unless header_value

      since = Time.httpdate(header_value)
      File.mtime(file).to_i <= since.to_i
    rescue ArgumentError
      false
    end

    def parse_range(header_value, file_size)
      return nil if header_value.nil? || header_value.empty?

      match = header_value.match(RANGE_PATTERN)
      # Per RFC 7233, an unparseable Range is treated as if absent: fall
      # through as nil so the caller serves a normal 200 instead of 416.
      return nil unless match

      first, last = match.captures
      if first.nil? && last.nil?
        nil
      elsif first.nil?
        suffix_range(last.to_i, file_size)
      elsif last.nil?
        open_range(first.to_i, file_size)
      else
        bounded_range(first.to_i, last.to_i, file_size)
      end
    end

    def suffix_range(suffix, file_size)
      return :unsatisfiable if suffix.zero? || file_size.zero?

      [file_size - suffix, 0].max..(file_size - 1)
    end

    def open_range(first, file_size)
      return :unsatisfiable if first >= file_size

      first..(file_size - 1)
    end

    def bounded_range(first, last, file_size)
      return :unsatisfiable if first > last || first >= file_size

      last = file_size - 1 if last >= file_size
      first..last
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
