# frozen_string_literal: true

require_relative "test_helper"

class CorsTest < Minitest::Test
  def setup
    @cors = Wsv::Cors.new
  end

  def test_allow_methods_returns_array
    assert_equal %w[GET HEAD OPTIONS], @cors.allow_methods
  end

  # `Cors#preflight` returns the preflight-specific headers only;
  # Server::Connection adds ACAO / Vary on top, uniformly.

  def test_preflight_returns_204
    response = @cors.preflight(req)

    assert_equal 204, response.status
  end

  def test_preflight_includes_allow_methods_and_max_age
    response = @cors.preflight(req)

    assert_equal "GET, HEAD, OPTIONS", response.headers["Access-Control-Allow-Methods"]
    assert_equal "86400", response.headers["Access-Control-Max-Age"]
  end

  def test_preflight_omits_acao_and_vary
    response = @cors.preflight(req)

    refute response.headers.key?("Access-Control-Allow-Origin")
    refute response.headers.key?("Vary")
  end

  def test_preflight_echoes_requested_headers
    response = @cors.preflight(req("access-control-request-headers" => "X-Custom, Authorization"))

    assert_equal "X-Custom, Authorization", response.headers["Access-Control-Allow-Headers"]
  end

  def test_preflight_omits_allow_headers_when_not_requested
    response = @cors.preflight(req)

    refute response.headers.key?("Access-Control-Allow-Headers")
  end

  def test_overlay_adds_acao_and_vary
    base = Wsv::Response.text(200)
    overlaid = @cors.overlay(base)

    assert_equal "*", overlaid.headers["Access-Control-Allow-Origin"]
    assert_equal "Origin", overlaid.headers["Vary"]
  end

  def test_overlay_preserves_existing_headers
    base = Wsv::Response.text(404)
    overlaid = @cors.overlay(base)

    assert_equal "text/plain; charset=utf-8", overlaid.headers["Content-Type"]
  end

  def test_overlay_returns_a_new_response_keeping_status
    base = Wsv::Response.text(404)
    overlaid = @cors.overlay(base)

    assert_equal 404, overlaid.status
  end

  private

  def req(headers = {})
    Wsv::Request.new(method: "OPTIONS", target: "/", version: "HTTP/1.1", headers: headers)
  end
end
