# frozen_string_literal: true

module Wsv
  class Response
    # Body for Server-Sent Events responses. The producer block receives the
    # client socket and writes SSE frames until it returns; the surrounding
    # Connection then closes the TCP connection. Write errors after the peer
    # disconnects (EPIPE, ECONNRESET, IOError) propagate out of #write_to and
    # are swallowed by Connection#write, so producers do not need their own
    # rescue. Producers should `io.flush` after each frame to defeat TCP
    # buffering.
    #
    # `bytesize` returns 0 because SSE streams have no a-priori known size.
    # AccessLog renders 0 bytes as `-` in Common Log Format.
    class SseBody
      def initialize(&producer)
        raise ArgumentError, "block required" unless producer

        @producer = producer
      end

      def to_s
        raise NotImplementedError, "SseBody has no static representation; use #write_to(io)"
      end

      def bytesize
        0
      end

      def write_to(io)
        @producer.call(io)
      end
    end
  end
end
