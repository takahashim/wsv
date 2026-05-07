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

  def test_redirect_normalizes_absolute_form_target_to_origin_form
    FileUtils.mkdir_p(File.join(@dir, "docs"))
    File.write(File.join(@dir, "docs", "index.html"), "x")

    response = @app.call(req("GET", "http://example.test/docs"))

    assert_equal 301, response.status
    assert_equal "/docs/", response.headers["Location"]
  end

  def test_head_omits_body_but_keeps_content_length
    File.write(File.join(@dir, "x.txt"), "hi")

    response = @app.call(req("HEAD", "/x.txt"))

    assert_equal "", response.body
    assert_equal "2", response.headers["Content-Length"]
  end

  def test_advertises_accept_ranges_on_200
    File.write(File.join(@dir, "x.txt"), "hi")

    response = @app.call(req("GET", "/x.txt"))

    assert_equal "bytes", response.headers["Accept-Ranges"]
  end

  def test_returns_304_when_if_modified_since_matches
    path = File.join(@dir, "x.txt")
    File.write(path, "hi")

    response = @app.call(req("GET", "/x.txt", "if-modified-since" => File.mtime(path).httpdate))

    assert_equal 304, response.status
    assert_equal "", response.body
    refute response.headers.key?("Content-Length")
  end

  def test_returns_200_when_if_modified_since_is_older
    path = File.join(@dir, "x.txt")
    File.write(path, "hi")
    older = (File.mtime(path) - 3600).httpdate

    response = @app.call(req("GET", "/x.txt", "if-modified-since" => older))

    assert_equal 200, response.status
    assert_equal "hi", response.body
  end

  def test_invalid_if_modified_since_is_ignored
    File.write(File.join(@dir, "x.txt"), "hi")

    response = @app.call(req("GET", "/x.txt", "if-modified-since" => "not a date"))

    assert_equal 200, response.status
  end

  def test_serves_byte_range
    File.write(File.join(@dir, "data.bin"), "abcdefghij")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=2-5"))

    assert_equal 206, response.status
    assert_equal "cdef", response.body
    assert_equal "4", response.headers["Content-Length"]
    assert_equal "bytes 2-5/10", response.headers["Content-Range"]
  end

  def test_serves_open_ended_range
    File.write(File.join(@dir, "data.bin"), "abcdefghij")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=7-"))

    assert_equal 206, response.status
    assert_equal "hij", response.body
    assert_equal "bytes 7-9/10", response.headers["Content-Range"]
  end

  def test_serves_suffix_range
    File.write(File.join(@dir, "data.bin"), "abcdefghij")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=-3"))

    assert_equal 206, response.status
    assert_equal "hij", response.body
    assert_equal "bytes 7-9/10", response.headers["Content-Range"]
  end

  def test_clamps_range_end_to_file_size
    File.write(File.join(@dir, "data.bin"), "abcdefghij")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=5-99"))

    assert_equal 206, response.status
    assert_equal "fghij", response.body
    assert_equal "bytes 5-9/10", response.headers["Content-Range"]
  end

  def test_unsatisfiable_range_returns_416
    File.write(File.join(@dir, "data.bin"), "abc")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=10-20"))

    assert_equal 416, response.status
    assert_equal "bytes */3", response.headers["Content-Range"]
  end

  def test_invalid_range_syntax_serves_full_content
    File.write(File.join(@dir, "data.bin"), "abc")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=garbage"))

    assert_equal 200, response.status
    assert_equal "abc", response.body
  end

  def test_head_with_range_omits_body_but_keeps_headers
    File.write(File.join(@dir, "data.bin"), "abcdefghij")

    response = @app.call(req("HEAD", "/data.bin", "range" => "bytes=0-2"))

    assert_equal 206, response.status
    assert_equal "", response.body
    assert_equal "3", response.headers["Content-Length"]
  end

  def test_spa_fallback_serves_index_for_missing_path
    File.write(File.join(@dir, "index.html"), "<h1>SPA</h1>")
    spa_app = Wsv::App.new(File.realpath(@dir), spa: true)

    response = spa_app.call(req("GET", "/users/123"))

    assert_equal 200, response.status
    assert_equal "<h1>SPA</h1>", response.body
    assert_equal "text/html; charset=utf-8", response.headers["Content-Type"]
  end

  def test_spa_fallback_head_serves_index_headers_without_body
    File.write(File.join(@dir, "index.html"), "<h1>SPA</h1>")
    spa_app = Wsv::App.new(File.realpath(@dir), spa: true)

    response = spa_app.call(req("HEAD", "/users/123"))

    assert_equal 200, response.status
    assert_equal "", response.body
    assert_equal "text/html; charset=utf-8", response.headers["Content-Type"]
    assert_equal "12", response.headers["Content-Length"]
  end

  def test_spa_disabled_returns_404_for_missing_path
    File.write(File.join(@dir, "index.html"), "<h1>SPA</h1>")

    response = @app.call(req("GET", "/users/123"))

    assert_equal 404, response.status
  end

  def test_spa_keeps_403_for_dotfile
    File.write(File.join(@dir, "index.html"), "<h1>SPA</h1>")
    File.write(File.join(@dir, ".env"), "secret")
    spa_app = Wsv::App.new(File.realpath(@dir), spa: true)

    response = spa_app.call(req("GET", "/.env"))

    assert_equal 403, response.status
  end

  def test_spa_keeps_403_for_path_traversal
    File.write(File.join(@dir, "index.html"), "<h1>SPA</h1>")
    spa_app = Wsv::App.new(File.realpath(@dir), spa: true)

    response = spa_app.call(req("GET", "/../etc/passwd"))

    assert_equal 403, response.status
  end

  def test_spa_returns_404_when_no_index_html
    spa_app = Wsv::App.new(File.realpath(@dir), spa: true)

    response = spa_app.call(req("GET", "/users/123"))

    assert_equal 404, response.status
  end

  def test_spa_serves_real_file_when_path_matches
    File.write(File.join(@dir, "index.html"), "<h1>SPA</h1>")
    File.write(File.join(@dir, "robots.txt"), "User-agent: *")
    spa_app = Wsv::App.new(File.realpath(@dir), spa: true)

    response = spa_app.call(req("GET", "/robots.txt"))

    assert_equal 200, response.status
    assert_equal "User-agent: *", response.body
  end

  def test_serves_single_byte_range
    File.write(File.join(@dir, "data.bin"), "abcdefghij")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=0-0"))

    assert_equal 206, response.status
    assert_equal "a", response.body
    assert_equal "1", response.headers["Content-Length"]
    assert_equal "bytes 0-0/10", response.headers["Content-Range"]
  end

  def test_inverted_range_returns_416
    File.write(File.join(@dir, "data.bin"), "abcdefghij")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=5-3"))

    assert_equal 416, response.status
    assert_equal "bytes */10", response.headers["Content-Range"]
  end

  def test_206_preserves_caching_headers
    path = File.join(@dir, "data.bin")
    File.write(path, "abcdefghij")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=2-5"))

    assert_equal 206, response.status
    assert_equal Wsv::MimeTypes.for_file("data.bin"), response.headers["Content-Type"]
    assert_equal File.mtime(path).httpdate, response.headers["Last-Modified"]
    assert_equal "no-cache", response.headers["Cache-Control"]
    assert_equal "bytes", response.headers["Accept-Ranges"]
  end

  def test_multipart_range_falls_through_to_200
    File.write(File.join(@dir, "data.bin"), "abcdefghij")

    response = @app.call(req("GET", "/data.bin", "range" => "bytes=0-2,5-7"))

    assert_equal 200, response.status
    assert_equal "abcdefghij", response.body
    refute response.headers.key?("Content-Range")
  end

  private

  def req(method, target, headers = {})
    Wsv::Request.new(method: method, target: target, version: "HTTP/1.1", headers: headers)
  end
end
