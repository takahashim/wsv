# frozen_string_literal: true

require "net/http"
require "socket"
require_relative "test_helper"

class ServerTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @server = nil
    @thread = nil
  end

  def teardown
    @server&.stop
    @thread&.join(2)
    FileUtils.remove_entry(@dir)
  end

  def test_serves_index
    File.write(File.join(@dir, "index.html"), "<h1>Hello</h1>")
    start_server

    response = get("/")

    assert_equal "200", response.code
    assert_equal "<h1>Hello</h1>", response.body
    assert_equal "text/html; charset=utf-8", response["content-type"]
    assert_equal "14", response["content-length"]
    assert_equal "no-cache", response["cache-control"]
  end

  def test_serves_file_with_mime_type
    File.write(File.join(@dir, "app.js"), "console.log('ok');")
    start_server

    response = get("/app.js")

    assert_equal "200", response.code
    assert_equal "console.log('ok');", response.body
    assert_equal "text/javascript; charset=utf-8", response["content-type"]
    assert_equal "18", response["content-length"]
  end

  def test_head_has_headers_without_body
    File.write(File.join(@dir, "style.css"), "body{}")
    start_server

    response = head("/style.css")

    assert_equal "200", response.code
    assert_nil response.body
    assert_equal "6", response["content-length"]
  end

  def test_directory_without_index_is_not_listed
    FileUtils.mkdir_p(File.join(@dir, "assets"))
    start_server

    response = get("/assets/")

    assert_equal "404", response.code
    assert_includes response.body, "404 Not Found"
  end

  def test_redirects_directory_without_trailing_slash
    FileUtils.mkdir_p(File.join(@dir, "docs"))
    File.write(File.join(@dir, "docs", "index.html"), "docs")
    start_server

    response = get("/docs")

    assert_equal "301", response.code
    assert_equal "/docs/", response["location"]
  end

  def test_rejects_path_traversal
    secret = File.join(File.dirname(@dir), "wsv-secret-#{$$}.txt")
    File.write(secret, "secret")
    start_server

    response = get("/../#{File.basename(secret)}")

    assert_equal "403", response.code
  ensure
    FileUtils.rm_f(secret) if secret
  end

  def test_rejects_dotfile_at_root
    File.write(File.join(@dir, ".env"), "API_KEY=secret")
    start_server

    response = get("/.env")

    assert_equal "403", response.code
  end

  def test_rejects_dotfile_in_subdir
    FileUtils.mkdir_p(File.join(@dir, "sub"))
    File.write(File.join(@dir, "sub", ".secret"), "secret")
    start_server

    response = get("/sub/.secret")

    assert_equal "403", response.code
  end

  def test_rejects_dot_directory
    FileUtils.mkdir_p(File.join(@dir, ".git"))
    File.write(File.join(@dir, ".git", "config"), "[remote]")
    start_server

    response = get("/.git/config")

    assert_equal "403", response.code
  end

  def test_rejects_url_encoded_traversal
    secret = File.join(File.dirname(@dir), "wsv-secret-#{$$}.txt")
    File.write(secret, "secret")
    start_server

    response = get("/%2e%2e/#{File.basename(secret)}")

    assert_equal "403", response.code
  ensure
    FileUtils.rm_f(secret) if secret
  end

  def test_returns_414_for_too_long_request_line
    start_server

    long_path = "/" + ("a" * 9000)
    socket = TCPSocket.open("127.0.0.1", @server.port)
    socket.write("GET #{long_path} HTTP/1.1\r\nHost: localhost\r\n\r\n")
    response = socket.read

    assert_includes response, "HTTP/1.1 414"
  ensure
    socket&.close
  end

  def test_returns_431_for_too_large_headers
    start_server

    socket = TCPSocket.open("127.0.0.1", @server.port)
    big = "X-Long: " + ("z" * 9000) + "\r\n"
    socket.write("GET / HTTP/1.1\r\n#{big}\r\n")
    response = socket.read

    assert_includes response, "HTTP/1.1 431"
  ensure
    socket&.close
  end

  def test_returns_408_for_idle_client
    start_server(read_timeout: 0.1)

    socket = TCPSocket.open("127.0.0.1", @server.port)
    response = socket.read

    assert_includes response, "HTTP/1.1 408"
  ensure
    socket&.close
  end

  def test_unsupported_method
    start_server

    response = raw_request("POST / HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 0\r\n\r\n")

    assert_includes response, "HTTP/1.1 405 Method Not Allowed"
    assert_includes response, "Allow: GET, HEAD"
  end

  private

  def start_server(read_timeout: Wsv::Server::DEFAULT_READ_TIMEOUT)
    @server = Wsv::Server.new(
      host: "127.0.0.1",
      port: free_port,
      root: @dir,
      out: StringIO.new,
      err: StringIO.new,
      read_timeout: read_timeout
    )
    @thread = Thread.new { @server.start }
    wait_until_ready
  end

  def free_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  def wait_until_ready
    deadline = Time.now + 2
    loop do
      TCPSocket.open("127.0.0.1", @server.port).close
      break
    rescue Errno::ECONNREFUSED
      raise if Time.now >= deadline

      sleep 0.01
    end
  end

  def get(path)
    Net::HTTP.get_response(URI("http://127.0.0.1:#{@server.port}#{path}"))
  end

  def head(path)
    Net::HTTP.start("127.0.0.1", @server.port) do |http|
      http.head(path)
    end
  end

  def raw_request(request)
    socket = TCPSocket.open("127.0.0.1", @server.port)
    socket.write(request)
    socket.read
  ensure
    socket&.close
  end
end
