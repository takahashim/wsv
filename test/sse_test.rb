# frozen_string_literal: true

require_relative "test_helper"

class SseBodyTest < Minitest::Test
  def test_requires_a_block
    assert_raises(ArgumentError) { Wsv::Response::SseBody.new }
  end

  def test_to_s_raises_not_implemented
    body = Wsv::Response::SseBody.new { |io| io }
    assert_raises(NotImplementedError) { body.to_s }
  end

  def test_bytesize_is_zero
    body = Wsv::Response::SseBody.new { |io| io }

    assert_equal 0, body.bytesize
  end

  def test_write_to_invokes_producer_with_io
    received_io = nil
    body = Wsv::Response::SseBody.new { |io| received_io = io }
    buffer = StringIO.new
    body.write_to(buffer)

    assert_equal buffer, received_io
  end

  def test_producer_can_write_multiple_chunks
    body = Wsv::Response::SseBody.new do |io|
      io.write("data: hello\n\n")
      io.write("data: world\n\n")
    end
    buffer = StringIO.new
    body.write_to(buffer)

    assert_equal "data: hello\n\ndata: world\n\n", buffer.string
  end
end

class ResponseSseTest < Minitest::Test
  def test_sse_helper_returns_response_with_sse_defaults
    response = Wsv::Response.sse { |io| io }

    assert_equal 200, response.status
    assert_equal "text/event-stream; charset=utf-8", response.headers["Content-Type"]
    assert_equal "no-cache", response.headers["Cache-Control"]
    assert_equal "no", response.headers["X-Accel-Buffering"]
  end

  def test_sse_helper_allows_custom_status
    response = Wsv::Response.sse(status: 503) { |io| io }

    assert_equal 503, response.status
  end

  def test_sse_helper_merges_extra_headers
    response = Wsv::Response.sse(headers: { "X-Custom" => "v" }) { |io| io }

    assert_equal "v", response.headers["X-Custom"]
    assert_equal "no-cache", response.headers["Cache-Control"]
  end

  def test_sse_helper_overrides_default_headers_when_supplied
    response = Wsv::Response.sse(headers: { "Content-Type" => "application/x-ndjson" }) { |io| io }

    assert_equal "application/x-ndjson", response.headers["Content-Type"]
  end

  def test_response_write_to_does_not_inject_content_length_for_sse
    response = Wsv::Response.sse do |io|
      io.write("data: hi\n\n")
    end
    buffer = StringIO.new
    response.write_to(buffer)

    refute_match(/^Content-Length:/i, buffer.string)
    assert_match(%r{^Content-Type: text/event-stream}i, buffer.string)
    assert_match(/data: hi\n\n\z/, buffer.string)
  end

  def test_bytesize_of_sse_response_is_zero
    response = Wsv::Response.sse { |io| io }

    assert_equal 0, response.bytesize
  end
end
