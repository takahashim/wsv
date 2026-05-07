# frozen_string_literal: true

require_relative "test_helper"

class BrowserLauncherTest < Minitest::Test
  def test_loopback_host_used_directly
    launcher = build(host: "127.0.0.1")

    assert_equal "http://127.0.0.1:8000/", launcher.send(:url)
  end

  def test_wildcard_v4_translated_to_loopback
    launcher = build(host: "0.0.0.0")

    assert_equal "http://127.0.0.1:8000/", launcher.send(:url)
  end

  def test_wildcard_v6_translated_to_loopback
    launcher = build(host: "::")

    assert_equal "http://[::1]:8000/", launcher.send(:url)
  end

  def test_ipv6_literal_host_is_bracketed
    launcher = build(host: "::1")

    assert_equal "http://[::1]:8000/", launcher.send(:url)
  end

  def test_specific_host_passes_through
    launcher = build(host: "192.168.1.5")

    assert_equal "http://192.168.1.5:8000/", launcher.send(:url)
  end

  def test_https_scheme_when_tls_present
    launcher = build(host: "127.0.0.1", tls: Object.new)

    assert_equal "https://127.0.0.1:8000/", launcher.send(:url)
  end

  def test_logs_when_platform_unsupported
    err = StringIO.new
    launcher = build(host: "127.0.0.1", err: err)
    launcher.define_singleton_method(:platform_command) { nil }

    launcher.launch

    assert_includes err.string, "not supported on this platform"
  end

  private

  def build(host:, tls: nil, err: StringIO.new)
    Wsv::Server::BrowserLauncher.new(host: host, port: 8000, tls: tls, err: err)
  end
end
