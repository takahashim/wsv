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
end
