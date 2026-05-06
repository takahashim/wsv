# frozen_string_literal: true

require "cgi"
require "socket"
require "time"
require "uri"

module Wsv
  class Server
    SERVER_NAME = "wsv/#{Wsv::VERSION}"

    MIME_TYPES = {
      ".css" => "text/css; charset=utf-8",
      ".gif" => "image/gif",
      ".html" => "text/html; charset=utf-8",
      ".htm" => "text/html; charset=utf-8",
      ".ico" => "image/x-icon",
      ".jpeg" => "image/jpeg",
      ".jpg" => "image/jpeg",
      ".js" => "text/javascript; charset=utf-8",
      ".json" => "application/json; charset=utf-8",
      ".mjs" => "text/javascript; charset=utf-8",
      ".pdf" => "application/pdf",
      ".png" => "image/png",
      ".svg" => "image/svg+xml; charset=utf-8",
      ".txt" => "text/plain; charset=utf-8",
      ".wasm" => "application/wasm",
      ".webp" => "image/webp",
      ".woff" => "font/woff",
      ".woff2" => "font/woff2"
    }.freeze

    STATUSES = {
      200 => "OK",
      301 => "Moved Permanently",
      400 => "Bad Request",
      403 => "Forbidden",
      404 => "Not Found",
      405 => "Method Not Allowed"
    }.freeze

    attr_reader :host, :port, :root

    def initialize(host:, port:, root:, out: $stdout, err: $stderr)
      @host = host
      @port = port
      @root = File.realpath(root)
      @out = out
      @err = err
      @running = false
    end

    def start
      @server = TCPServer.new(host, port)
      @running = true
      log_startup

      trap_signals
      accept_loop
    ensure
      close
    end

    def stop
      @running = false
      close
    end

    def handle(client)
      request_line = client.gets
      return unless request_line

      headers = read_headers(client)
      method, target, version = request_line.split(/\s+/, 3)
      version = version&.strip

      unless method && target && version&.start_with?("HTTP/")
        return write_error(client, 400)
      end

      response = build_response(method, target)
      write_response(client, response)
    rescue StandardError => e
      @err.puts "wsv: #{e.class}: #{e.message}"
      write_error(client, 400) unless client.closed?
    ensure
      client.close unless client.closed?
    end

    private

    def accept_loop
      while @running
        begin
          client = @server.accept
          handle(client)
        rescue IOError, Errno::EBADF
          break unless @running
        end
      end
    end

    def close
      @server&.close unless @server&.closed?
    end

    def trap_signals
      %w[INT TERM].each do |signal|
        Signal.trap(signal) do
          @out.puts "\nStopping wsv."
          stop
        end
      end
    rescue ArgumentError
      nil
    end

    def log_startup
      @out.puts "Serving: #{root}"
      @out.puts "Bind:    #{url_for(host)}"
      @out.puts "Local:   #{url_for("127.0.0.1")}" unless localhost?(host)
      @out.puts "Stop:    Ctrl-C"
    end

    def url_for(display_host)
      "http://#{display_host}:#{port}/"
    end

    def localhost?(display_host)
      display_host == "127.0.0.1" || display_host == "localhost" || display_host == "::1"
    end

    def read_headers(client)
      headers = {}
      while (line = client.gets)
        line = line.delete_suffix("\r\n").delete_suffix("\n")
        break if line.empty?

        name, value = line.split(":", 2)
        headers[name.downcase] = value.strip if name && value
      end
      headers
    end

    def build_response(method, target)
      return simple_response(405, "Method Not Allowed", {"Allow" => "GET, HEAD"}) unless %w[GET HEAD].include?(method)

      head = method == "HEAD"
      path, query = target.split("?", 2)
      resolved = resolve_path(path)
      return simple_response(resolved[:status], STATUSES.fetch(resolved[:status]), head: head) unless resolved[:ok]

      if resolved[:redirect]
        location = path.end_with?("/") ? path : "#{path}/"
        location += "?#{query}" if query && !query.empty?
        return simple_response(301, "Moved Permanently", {"Location" => location}, head: head)
      end

      file_response(resolved[:file], head: head)
    end

    def resolve_path(raw_path)
      decoded = decode_path(raw_path)
      return {ok: false, status: 400} unless decoded

      relative = decoded.sub(%r{\A/+}, "")
      return {ok: false, status: 403} if hidden_segment?(relative)

      candidate = File.expand_path(relative, root)
      return {ok: false, status: 403} unless within_root?(candidate)
      return {ok: false, status: 404} unless File.exist?(candidate)

      if File.directory?(candidate)
        return {ok: true, redirect: true} unless decoded.end_with?("/")

        index = File.join(candidate, "index.html")
        return {ok: false, status: 404} unless File.file?(index)

        return {ok: true, file: index}
      end

      return {ok: false, status: 404} unless File.file?(candidate)

      {ok: true, file: candidate}
    end

    def hidden_segment?(relative)
      relative.split("/").any? do |segment|
        next false if segment.empty? || segment == "." || segment == ".."

        segment.start_with?(".")
      end
    end

    def decode_path(raw_path)
      path = URI(raw_path).path
      CGI.unescape(path)
    rescue ArgumentError, URI::InvalidURIError
      nil
    end

    def within_root?(path)
      real = if File.exist?(path)
        File.realpath(path)
      else
        File.expand_path(path)
      end

      real == root || real.start_with?("#{root}#{File::SEPARATOR}")
    rescue Errno::ENOENT
      File.expand_path(path).start_with?("#{root}#{File::SEPARATOR}")
    end

    def file_response(file, head:)
      body = head ? "" : File.binread(file)
      headers = {
        "Content-Type" => content_type(file),
        "Content-Length" => File.size(file).to_s,
        "Last-Modified" => File.mtime(file).httpdate,
        "Cache-Control" => "no-cache"
      }
      Response.new(status: 200, headers: headers, body: body)
    end

    def simple_response(status, message, headers = {}, head: false)
      body = "#{status} #{message}\n"
      Response.new(
        status: status,
        headers: {
          "Content-Type" => "text/plain; charset=utf-8",
          "Content-Length" => body.bytesize.to_s,
          "Cache-Control" => "no-cache"
        }.merge(headers),
        body: head ? "" : body
      )
    end

    def write_error(client, status)
      write_response(client, simple_response(status, STATUSES.fetch(status)))
    end

    def write_response(client, response)
      reason = STATUSES.fetch(response.status)
      client.write "HTTP/1.1 #{response.status} #{reason}\r\n"
      client.write "Server: #{SERVER_NAME}\r\n"
      client.write "Connection: close\r\n"
      response.headers.each do |name, value|
        client.write "#{name}: #{value}\r\n"
      end
      client.write "\r\n"
      client.write response.body
    end

    def content_type(file)
      MIME_TYPES.fetch(File.extname(file).downcase, "application/octet-stream")
    end

    Response = Struct.new(:status, :headers, :body, keyword_init: true)
  end
end
