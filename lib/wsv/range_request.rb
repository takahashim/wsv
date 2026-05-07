# frozen_string_literal: true

module Wsv
  # Parses an HTTP `Range` header (RFC 7233) against a known file size.
  class RangeRequest
    PATTERN = /\Abytes=(\d+)?-(\d+)?\z/

    class Result
      attr_reader :bounds

      def initialize(kind:, bounds: nil)
        @kind = kind
        @bounds = bounds
      end

      def full?
        @kind == :full
      end

      def partial?
        @kind == :partial
      end

      def unsatisfiable?
        @kind == :unsatisfiable
      end

      def self.full
        new(kind: :full)
      end

      def self.partial(bounds)
        new(kind: :partial, bounds: bounds)
      end

      def self.unsatisfiable
        new(kind: :unsatisfiable)
      end
    end

    def self.parse(header_value, file_size)
      new(header_value, file_size).parse
    end

    def initialize(header_value, file_size)
      @header_value = header_value
      @file_size = file_size
    end

    def parse
      return Result.full if @header_value.nil? || @header_value.empty?

      match = @header_value.match(PATTERN)
      # Per RFC 7233, an unparseable Range is treated as if absent: return
      # full so the caller serves a normal 200 instead of 416.
      return Result.full unless match

      first, last = match.captures
      if first.nil? && last.nil?
        Result.full
      elsif first.nil?
        suffix_range(last.to_i)
      elsif last.nil?
        open_range(first.to_i)
      else
        bounded_range(first.to_i, last.to_i)
      end
    end

    private

    def suffix_range(suffix)
      return Result.unsatisfiable if suffix.zero? || @file_size.zero?

      Result.partial([@file_size - suffix, 0].max..(@file_size - 1))
    end

    def open_range(first)
      return Result.unsatisfiable if first >= @file_size

      Result.partial(first..(@file_size - 1))
    end

    def bounded_range(first, last)
      return Result.unsatisfiable if first > last || first >= @file_size

      last = @file_size - 1 if last >= @file_size
      Result.partial(first..last)
    end
  end
end
