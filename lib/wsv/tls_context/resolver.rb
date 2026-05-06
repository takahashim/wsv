# frozen_string_literal: true

require "openssl"

module Wsv
  class TlsContext
    class Resolver
      XDG_DIR = "wsv"
      CERT_FILE = "cert.pem"
      KEY_FILE = "key.pem"

      def self.resolve(cert_path: nil, key_path: nil)
        new(cert_path: cert_path, key_path: key_path).resolve
      end

      def initialize(cert_path: nil, key_path: nil)
        @cert_path = cert_path
        @key_path = key_path
      end

      def resolve
        return from_files(@cert_path, @key_path) if @cert_path && @key_path

        raise ArgumentError, "--cert and --key must be provided together" if @cert_path || @key_path

        xdg = xdg_pair
        return from_files(*xdg) if xdg

        ephemeral
      end

      private

      def from_files(cert_path, key_path)
        TlsContext.new(
          cert: OpenSSL::X509::Certificate.new(File.read(cert_path)),
          key: OpenSSL::PKey.read(File.read(key_path))
        )
      end

      def ephemeral
        key = OpenSSL::PKey::RSA.new(2048)
        cert = SelfSignedCert.build(key)
        TlsContext.new(cert: cert, key: key, ephemeral: true)
      end

      def xdg_pair
        cert = File.join(xdg_base, XDG_DIR, CERT_FILE)
        key  = File.join(xdg_base, XDG_DIR, KEY_FILE)
        cert_exists = File.exist?(cert)
        key_exists  = File.exist?(key)
        return [cert, key] if cert_exists && key_exists

        if cert_exists ^ key_exists
          raise ArgumentError, "found only one of #{cert} / #{key} -- both must exist or neither"
        end

        nil
      end

      def xdg_base
        ENV["XDG_CONFIG_HOME"] || File.join(Dir.home, ".config")
      end
    end
  end
end
