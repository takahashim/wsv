# frozen_string_literal: true

require "openssl"
require "securerandom"

module Wsv
  class TlsContext
    class SelfSignedCert
      SUBJECT = "/CN=localhost"
      SAN = "DNS:localhost,IP:127.0.0.1,IP:::1"
      VALIDITY_SECONDS = 365 * 24 * 60 * 60

      def self.build(key)
        new(key).build
      end

      def initialize(key)
        @key = key
      end

      def build
        cert = OpenSSL::X509::Certificate.new
        cert.version = 2
        cert.serial = SecureRandom.random_number(2**63)
        cert.subject = OpenSSL::X509::Name.parse(SUBJECT)
        cert.issuer = cert.subject
        cert.public_key = @key.public_key
        cert.not_before = Time.now - 60
        cert.not_after = Time.now + VALIDITY_SECONDS
        ef = OpenSSL::X509::ExtensionFactory.new(cert, cert)
        cert.add_extension(ef.create_extension("subjectAltName", SAN))
        cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE", true))
        cert.sign(@key, OpenSSL::Digest.new("SHA256"))
        cert
      end
    end
  end
end
