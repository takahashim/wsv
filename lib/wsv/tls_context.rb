# frozen_string_literal: true

require "openssl"
require_relative "tls_context/self_signed_cert"
require_relative "tls_context/resolver"

module Wsv
  class TlsContext
    attr_reader :cert, :key

    def initialize(cert:, key:, ephemeral: false)
      @cert = cert
      @key = key
      @ephemeral = ephemeral
    end

    def ephemeral?
      @ephemeral
    end

    def to_ssl_context
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.cert = @cert
      ctx.key = @key
      ctx.min_version = OpenSSL::SSL::TLS1_2_VERSION
      ctx
    end
  end
end
