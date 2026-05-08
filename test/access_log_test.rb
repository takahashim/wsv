# frozen_string_literal: true

require_relative "test_helper"

class AccessLogTest < Minitest::Test
  def test_records_clf_line_for_serviced_request
    out = StringIO.new
    log = Wsv::Server::AccessLog.new(out: out)

    log.record(
      remote_addr: "127.0.0.1",
      request: build_request(method: "GET", target: "/index.html", version: "HTTP/1.1"),
      status: 200,
      bytes: 1234
    )

    assert_match(%r{\A127\.0\.0\.1 - - \[\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4}\] }, out.string)
    assert_includes out.string, %("GET /index.html HTTP/1.1" 200 1234)
  end

  def test_uses_dash_for_zero_bytes
    out = StringIO.new
    Wsv::Server::AccessLog.new(out: out).record(
      remote_addr: "127.0.0.1",
      request: build_request(method: "HEAD", target: "/", version: "HTTP/1.1"),
      status: 200,
      bytes: 0
    )

    assert_match(/200 -\z/, out.string.chomp)
  end

  def test_uses_dash_when_remote_addr_unknown
    out = StringIO.new
    Wsv::Server::AccessLog.new(out: out).record(
      remote_addr: nil,
      request: build_request(method: "GET", target: "/", version: "HTTP/1.1"),
      status: 200,
      bytes: 1
    )

    assert out.string.start_with?("- - - ")
  end

  def test_uses_dash_when_request_unparsed
    out = StringIO.new
    Wsv::Server::AccessLog.new(out: out).record(
      remote_addr: "127.0.0.1",
      request: nil,
      status: 408,
      bytes: 11
    )

    assert_includes out.string, %("-" 408 11)
  end

  def test_sanitizes_control_characters_in_request_line
    out = StringIO.new
    Wsv::Server::AccessLog.new(out: out).record(
      remote_addr: "127.0.0.1",
      request: build_request(method: "GET", target: "/x\r\ninjected:1", version: "HTTP/1.1"),
      status: 400,
      bytes: 0
    )

    refute_includes out.string, "\r"
    assert_equal 1, out.string.count("\n")
    assert_includes out.string, '\\x0d\\x0a'
  end

  def test_sanitizes_quotes_in_request_target
    out = StringIO.new
    Wsv::Server::AccessLog.new(out: out).record(
      remote_addr: "127.0.0.1",
      request: build_request(method: "GET", target: %(/x"y), version: "HTTP/1.1"),
      status: 200,
      bytes: 1
    )

    assert_includes out.string, '\\x22'
  end

  def test_null_access_log_is_silent
    log = Wsv::Server::NullAccessLog.new

    assert_nil log.record(remote_addr: "127.0.0.1", request: nil, status: 200, bytes: 0)
  end

  private

  def build_request(method:, target:, version:)
    Wsv::Request.new(method: method, target: target, version: version, headers: {})
  end
end
