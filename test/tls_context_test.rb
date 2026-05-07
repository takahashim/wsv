# frozen_string_literal: true

require_relative "test_helper"

class TlsContextTest < Minitest::Test
  def test_to_ssl_context_returns_configured_ssl_context
    key = OpenSSL::PKey::RSA.new(2048)
    cert = Wsv::TlsContext::SelfSignedCert.build(key)
    tls = Wsv::TlsContext.new(cert: cert, key: key)

    ssl = tls.to_ssl_context

    assert_kind_of OpenSSL::SSL::SSLContext, ssl
    assert_equal cert, ssl.cert
    assert_equal key, ssl.key
  end

  def test_ephemeral_predicate
    key = OpenSSL::PKey::RSA.new(2048)
    cert = Wsv::TlsContext::SelfSignedCert.build(key)

    refute_predicate Wsv::TlsContext.new(cert: cert, key: key), :ephemeral?
    assert_predicate Wsv::TlsContext.new(cert: cert, key: key, ephemeral: true), :ephemeral?
  end
end

class SelfSignedCertTest < Minitest::Test
  def test_subject_is_localhost
    cert = build

    assert_equal "/CN=localhost", cert.subject.to_s
  end

  def test_san_includes_localhost_and_loopback
    san = build.extensions.find { |ext| ext.oid == "subjectAltName" }.value

    assert_includes san, "DNS:localhost"
    assert_includes san, "IP Address:127.0.0.1"
    assert_includes san, "IP Address:0:0:0:0:0:0:0:1"
  end

  def test_signed_with_provided_key
    key = OpenSSL::PKey::RSA.new(2048)
    cert = Wsv::TlsContext::SelfSignedCert.build(key)

    assert cert.verify(key.public_key)
  end

  private

  def build
    Wsv::TlsContext::SelfSignedCert.build(OpenSSL::PKey::RSA.new(2048))
  end
end

class TlsContextResolverTest < Minitest::Test
  def test_resolves_explicit_paths
    Dir.mktmpdir do |dir|
      cert_path, key_path = write_self_signed(dir)

      tls = Wsv::TlsContext::Resolver.resolve(cert_path: cert_path, key_path: key_path)

      refute_predicate tls, :ephemeral?
    end
  end

  def test_requires_both_cert_and_key
    assert_raises(ArgumentError) do
      Wsv::TlsContext::Resolver.resolve(cert_path: "/some/cert.pem", key_path: nil)
    end

    assert_raises(ArgumentError) do
      Wsv::TlsContext::Resolver.resolve(cert_path: nil, key_path: "/some/key.pem")
    end
  end

  def test_uses_xdg_when_present
    Dir.mktmpdir do |xdg|
      wsv_dir = File.join(xdg, "wsv")
      FileUtils.mkdir_p(wsv_dir)
      write_self_signed(wsv_dir, cert_name: "cert.pem", key_name: "key.pem")

      with_env("XDG_CONFIG_HOME" => xdg) do
        tls = Wsv::TlsContext::Resolver.resolve

        refute_predicate tls, :ephemeral?
      end
    end
  end

  def test_falls_back_to_ephemeral_when_no_xdg
    Dir.mktmpdir do |xdg|
      with_env("XDG_CONFIG_HOME" => xdg) do
        tls = Wsv::TlsContext::Resolver.resolve

        assert_predicate tls, :ephemeral?
      end
    end
  end

  def test_errors_when_only_one_xdg_file_present
    Dir.mktmpdir do |xdg|
      wsv_dir = File.join(xdg, "wsv")
      FileUtils.mkdir_p(wsv_dir)
      File.write(File.join(wsv_dir, "cert.pem"), "stub")

      with_env("XDG_CONFIG_HOME" => xdg) do
        assert_raises(ArgumentError) { Wsv::TlsContext::Resolver.resolve }
      end
    end
  end

  def test_raises_openssl_error_for_malformed_cert
    Dir.mktmpdir do |dir|
      _cert_path, key_path = write_self_signed(dir)
      bad_cert = File.join(dir, "bad-cert.pem")
      File.write(bad_cert, "this is not a PEM\n")

      assert_raises(OpenSSL::X509::CertificateError) do
        Wsv::TlsContext::Resolver.resolve(cert_path: bad_cert, key_path: key_path)
      end
    end
  end

  def test_raises_openssl_error_for_malformed_key
    Dir.mktmpdir do |dir|
      cert_path, _key_path = write_self_signed(dir)
      bad_key = File.join(dir, "bad-key.pem")
      File.write(bad_key, "this is not a PEM\n")

      assert_raises(OpenSSL::PKey::PKeyError) do
        Wsv::TlsContext::Resolver.resolve(cert_path: cert_path, key_path: bad_key)
      end
    end
  end

  def test_raises_argument_error_when_cert_and_key_do_not_match
    Dir.mktmpdir do |dir|
      cert_path, = write_self_signed(dir, cert_name: "a.pem", key_name: "a.key")
      _, foreign_key = write_self_signed(dir, cert_name: "b.pem", key_name: "b.key")

      err = assert_raises(ArgumentError) do
        Wsv::TlsContext::Resolver.resolve(cert_path: cert_path, key_path: foreign_key)
      end

      assert_includes err.message, "does not match"
    end
  end

  private

  def write_self_signed(dir, cert_name: "test-cert.pem", key_name: "test-key.pem")
    key = OpenSSL::PKey::RSA.new(2048)
    cert = Wsv::TlsContext::SelfSignedCert.build(key)
    cert_path = File.join(dir, cert_name)
    key_path = File.join(dir, key_name)
    File.write(cert_path, cert.to_pem)
    File.write(key_path, key.to_pem)
    [cert_path, key_path]
  end

  def with_env(overrides)
    original = ENV.to_h
    overrides.each { |k, v| ENV[k] = v }
    yield
  ensure
    ENV.replace(original)
  end
end
