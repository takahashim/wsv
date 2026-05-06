# frozen_string_literal: true

require_relative "test_helper"

class RequestTest < Minitest::Test
  def test_parse_simple_get
    io = StringIO.new("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")

    request = Wsv::Request.parse(io)

    assert_equal "GET", request.method
    assert_equal "/", request.target
    assert_equal "HTTP/1.1", request.version
    assert_equal "localhost", request.headers["host"]
  end

  def test_parse_empty_returns_symbol
    assert_equal :empty, Wsv::Request.parse(StringIO.new(""))
  end

  def test_parse_malformed_returns_symbol
    assert_equal :malformed, Wsv::Request.parse(StringIO.new("garbage line\r\n"))
  end

  def test_request_line_too_long_raises_414
    long_path = "/" + ("a" * 9000)
    io = StringIO.new("GET #{long_path} HTTP/1.1\r\nHost: x\r\n\r\n")

    error = assert_raises(Wsv::Request::TooLarge) { Wsv::Request.parse(io) }

    assert_equal 414, error.status_code
  end

  def test_too_many_headers_raises_431
    headers = (1..200).map { |i| "X-Custom-#{i}: x\r\n" }.join
    io = StringIO.new("GET / HTTP/1.1\r\n#{headers}\r\n")

    error = assert_raises(Wsv::Request::TooLarge) { Wsv::Request.parse(io) }

    assert_equal 431, error.status_code
  end

  def test_header_total_too_large_raises_431
    big_value = "a" * 5000
    headers = (1..5).map { |i| "X-Big-#{i}: #{big_value}\r\n" }.join
    io = StringIO.new("GET / HTTP/1.1\r\n#{headers}\r\n")

    error = assert_raises(Wsv::Request::TooLarge) { Wsv::Request.parse(io) }

    assert_equal 431, error.status_code
  end

  def test_single_header_line_too_long_raises_431
    big_header = "X-Long: " + ("z" * 9000) + "\r\n"
    io = StringIO.new("GET / HTTP/1.1\r\n#{big_header}\r\n")

    error = assert_raises(Wsv::Request::TooLarge) { Wsv::Request.parse(io) }

    assert_equal 431, error.status_code
  end
end
