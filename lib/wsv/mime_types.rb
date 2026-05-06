# frozen_string_literal: true

module Wsv
  module MimeTypes
    DEFAULT = "application/octet-stream"

    TABLE = {
      ".css" => "text/css; charset=utf-8",
      ".gif" => "image/gif",
      ".html" => "text/html; charset=utf-8",
      ".htm" => "text/html; charset=utf-8",
      ".ico" => "image/x-icon",
      ".jpeg" => "image/jpeg",
      ".jpg" => "image/jpeg",
      ".js" => "text/javascript; charset=utf-8",
      ".json" => "application/json; charset=utf-8",
      ".mjs" => "text/javascript; charset=utf-8",
      ".pdf" => "application/pdf",
      ".png" => "image/png",
      ".svg" => "image/svg+xml; charset=utf-8",
      ".txt" => "text/plain; charset=utf-8",
      ".wasm" => "application/wasm",
      ".webp" => "image/webp",
      ".woff" => "font/woff",
      ".woff2" => "font/woff2"
    }.freeze

    def self.for_file(file)
      TABLE.fetch(File.extname(file).downcase, DEFAULT)
    end
  end
end
