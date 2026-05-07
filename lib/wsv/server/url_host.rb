# frozen_string_literal: true

module Wsv
  class Server
    # Formats a host for inclusion in a URL. IPv6 literals are bracketed
    # (RFC 3986); zone identifiers (`%eth0` etc.) are percent-encoded
    # (RFC 6874).
    module UrlHost
      module_function

      def format(host)
        host.include?(":") ? "[#{host.gsub('%', '%25')}]" : host
      end
    end
  end
end
