# frozen_string_literal: true

require_relative "test_helper"

class ResponseTest < Minitest::Test
  def test_rejects_crlf_in_header_value
    assert_raises(ArgumentError) do
      Wsv::Response.new(status: 200, headers: { "X-Foo" => "bad\r\nInjected: yes" })
    end
  end

  def test_rejects_lf_in_header_value
    assert_raises(ArgumentError) do
      Wsv::Response.new(status: 200, headers: { "X-Foo" => "bad\nthing" })
    end
  end

  def test_rejects_crlf_in_header_name
    assert_raises(ArgumentError) do
      Wsv::Response.new(status: 200, headers: { "X-Bad\r\n" => "value" })
    end
  end

  def test_rejects_colon_in_header_name
    assert_raises(ArgumentError) do
      Wsv::Response.new(status: 200, headers: { "X-Foo: extra" => "value" })
    end
  end

  def test_accepts_normal_headers
    Wsv::Response.new(
      status: 200,
      headers: {
        "Content-Type" => "text/html; charset=utf-8",
        "Allow" => "GET, HEAD",
        "Location" => "/docs/?q=1"
      }
    )
  end

  def test_text_factory_produces_writable_response
    response = Wsv::Response.text(404)
    io = StringIO.new
    response.write_to(io)

    assert_includes io.string, "HTTP/1.1 404 Not Found"
  end

  def test_write_to_emits_nosniff_header
    response = Wsv::Response.text(200)
    io = StringIO.new
    response.write_to(io)

    assert_includes io.string, "X-Content-Type-Options: nosniff"
  end

  def test_file_response_streams_via_io_copy_stream
    Dir.mktmpdir do |dir|
      path = File.join(dir, "data.bin")
      File.binwrite(path, "abcdefghij")

      response = Wsv::Response.file(path)
      io = StringIO.new
      response.write_to(io)

      assert_includes io.string, "HTTP/1.1 200 OK"
      assert io.string.end_with?("abcdefghij"), "expected file bytes at end of response"
    end
  end

  def test_file_response_does_not_eagerly_read_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "data.bin")
      File.binwrite(path, "abcdefghij")

      response = Wsv::Response.file(path)
      File.delete(path)

      assert_equal 200, response.status
      assert_equal "10", response.headers["Content-Length"]
    end
  end

  def test_file_response_streams_byte_range
    Dir.mktmpdir do |dir|
      path = File.join(dir, "data.bin")
      File.binwrite(path, "abcdefghij")

      response = Wsv::Response.file(path, range: 2..5)
      io = StringIO.new
      response.write_to(io)

      assert_includes io.string, "HTTP/1.1 206 Partial Content"
      assert io.string.end_with?("cdef"), "expected only the requested range"
    end
  end
end
