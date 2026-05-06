# frozen_string_literal: true

require "uri"

module Wsv
  class PathResolver
    class Result
      attr_reader :status, :file

      def initialize(kind:, status: nil, file: nil)
        @kind = kind
        @status = status
        @file = file
      end

      def file?
        @kind == :file
      end

      def redirect?
        @kind == :redirect
      end

      def error?
        @kind == :error
      end

      def self.file(path)
        new(kind: :file, status: 200, file: path)
      end

      def self.redirect
        new(kind: :redirect, status: 301)
      end

      def self.error(status)
        new(kind: :error, status: status)
      end
    end

    def initialize(root)
      @root = root
    end

    def resolve(raw_path)
      decoded = decode(raw_path)
      return Result.error(400) unless decoded

      relative = decoded.sub(%r{\A/+}, "")
      return Result.error(403) if hidden_segment?(relative)

      candidate = File.expand_path(relative, @root)
      return Result.error(403) unless within_root?(candidate)
      return Result.error(404) unless File.exist?(candidate)

      if File.directory?(candidate)
        return Result.redirect unless decoded.end_with?("/")

        index = File.join(candidate, "index.html")
        return Result.error(404) unless File.file?(index)

        return Result.file(index)
      end

      return Result.error(404) unless File.file?(candidate)

      Result.file(candidate)
    end

    private

    def decode(raw_path)
      path = URI(raw_path.to_s).path
      percent_decode(path)
    rescue URI::InvalidURIError
      nil
    end

    def percent_decode(string)
      decoded = string.gsub(/%([0-9a-fA-F]{2})/) { ::Regexp.last_match(1).hex.chr }
      decoded.force_encoding(Encoding::UTF_8)
      return nil unless decoded.valid_encoding?

      decoded
    end

    def hidden_segment?(relative)
      relative.split("/").any? do |segment|
        next false if segment.empty? || segment == "." || segment == ".."

        segment.start_with?(".")
      end
    end

    def within_root?(path)
      real = if File.exist?(path)
        File.realpath(path)
      else
        File.expand_path(path)
      end

      real == @root || real.start_with?("#{@root}#{File::SEPARATOR}")
    rescue Errno::ENOENT
      File.expand_path(path).start_with?("#{@root}#{File::SEPARATOR}")
    end
  end
end
