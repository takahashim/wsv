# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "fileutils"
require "stringio"
require "tmpdir"
require "wsv"

module TlsTestHelpers
  def ephemeral_tls
    key = OpenSSL::PKey::RSA.new(2048)
    cert = Wsv::TlsContext::SelfSignedCert.build(key)
    Wsv::TlsContext.new(cert: cert, key: key, ephemeral: true)
  end
end
