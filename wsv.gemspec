# frozen_string_literal: true

require_relative "lib/wsv/version"

Gem::Specification.new do |spec|
  spec.name = "wsv"
  spec.version = Wsv::VERSION
  spec.authors = ["takahashim"]
  spec.email = ["takahashimm@gmail.com"]

  spec.summary = "A tiny static web server for local previews."
  spec.description = "wsv serves a local directory over HTTP from a zero-config CLI."
  spec.homepage = "https://rubygems.org/gems/wsv"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/takahashim/wsv",
    "changelog_uri" => "https://github.com/takahashim/wsv/blob/main/CHANGELOG.md"
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
