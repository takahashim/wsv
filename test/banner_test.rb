# frozen_string_literal: true

require_relative "test_helper"

class BannerTest < Minitest::Test
  include TlsTestHelpers

  ROOT = Dir.tmpdir

  def test_warns_when_binding_to_non_loopback
    err = StringIO.new
    build(host: "0.0.0.0", err: err).emit

    assert_includes err.string, "WARNING"
    assert_includes err.string, "0.0.0.0"
  end

  def test_no_warning_for_loopback_bind
    err = StringIO.new
    build(host: "127.0.0.1", err: err).emit

    refute_includes err.string, "WARNING"
  end

  def test_brackets_ipv6_address_in_url
    out = StringIO.new
    build(host: "::1", port: 8000, out: out).emit

    assert_includes out.string, "http://[::1]:8000/"
    refute_includes out.string, "http://::1:8000/"
  end

  def test_percent_encodes_ipv6_zone_identifier
    out = StringIO.new
    build(host: "fe80::1%eth0", port: 8000, out: out).emit

    assert_includes out.string, "http://[fe80::1%25eth0]:8000/"
  end

  def test_logs_https_scheme_when_tls_enabled
    out = StringIO.new
    build(host: "127.0.0.1", port: 8000, out: out, tls: ephemeral_tls).emit

    assert_includes out.string, "https://"
  end

  def test_warns_about_self_signed_cert
    err = StringIO.new
    build(host: "127.0.0.1", err: err, tls: ephemeral_tls).emit

    assert_includes err.string, "self-signed"
  end

  private

  def build(host:, port: 0, root: ROOT, out: StringIO.new, err: StringIO.new, tls: nil)
    Wsv::Server::Banner.new(host: host, port: port, root: root, out: out, err: err, tls: tls)
  end
end
