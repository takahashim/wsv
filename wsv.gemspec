# frozen_string_literal: true

require_relative "lib/wsv/version"

Gem::Specification.new do |spec|
  spec.name = "wsv"
  spec.version = Wsv::VERSION
  spec.authors = ["takahashim"]
  spec.email = ["takahashimm@gmail.com"]

  spec.summary = "A zero-dependency static preview server for Ruby projects."
  spec.description = "wsv is a Ruby CLI that previews a directory over HTTP/HTTPS. Stdlib-only, no runtime dependencies. Defensive by design: blocks dotfiles, binds to loopback, ships with TLS and CORS."
  spec.homepage = "https://github.com/takahashim/wsv"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "changelog_uri" => "https://github.com/takahashim/wsv/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "CHANGELOG.md",
    "LICENSE.txt",
    "README.md",
    "bin/wsv",
    "lib/**/*.rb",
    "test/**/*.rb",
    "wsv.gemspec"
  ]
  spec.bindir = "bin"
  spec.executables = ["wsv"]
  spec.require_paths = ["lib"]
end
