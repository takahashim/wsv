# frozen_string_literal: true

require_relative "test_helper"

class AppTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @app = Wsv::App.new(File.realpath(@dir))
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_returns_file_response
    File.write(File.join(@dir, "hello.txt"), "hi")

    response = @app.call(req("GET", "/hello.txt"))

    assert_equal 200, response.status
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_equal "2", response.headers["Content-Length"]
    assert_equal "hi", response.body
  end

  def test_method_not_allowed
    response = @app.call(req("POST", "/"))

    assert_equal 405, response.status
    assert_equal "GET, HEAD", response.headers["Allow"]
  end

  def test_dotfile_forbidden
    File.write(File.join(@dir, ".env"), "secret")

    response = @app.call(req("GET", "/.env"))

    assert_equal 403, response.status
  end

  def test_path_traversal_forbidden
    response = @app.call(req("GET", "/../etc/passwd"))

    assert_equal 403, response.status
  end

  def test_url_encoded_traversal_forbidden
    response = @app.call(req("GET", "/%2e%2e/passwd"))

    assert_equal 403, response.status
  end

  def test_redirect_preserves_query
    FileUtils.mkdir_p(File.join(@dir, "docs"))
    File.write(File.join(@dir, "docs", "index.html"), "x")

    response = @app.call(req("GET", "/docs?q=1"))

    assert_equal 301, response.status
    assert_equal "/docs/?q=1", response.headers["Location"]
  end

  def test_head_omits_body_but_keeps_content_length
    File.write(File.join(@dir, "x.txt"), "hi")

    response = @app.call(req("HEAD", "/x.txt"))

    assert_equal "", response.body
    assert_equal "2", response.headers["Content-Length"]
  end

  private

  def req(method, target)
    Wsv::Request.new(method: method, target: target, version: "HTTP/1.1", headers: {})
  end
end
