# frozen_string_literal: true

module Wsv
  class Server
    # Wraps an IO with a shared deadline so each subsequent read is bounded by
    # the time remaining until the deadline. Used to enforce a single budget
    # across the request line and all header lines.
    class DeadlineReader
      def initialize(io, deadline)
        @io = io
        @deadline = deadline
      end

      def gets(eol, limit)
        remaining = @deadline - Time.now
        raise IO::TimeoutError if remaining <= 0

        @io.to_io.timeout = remaining
        @io.gets(eol, limit)
      end
    end
  end
end
