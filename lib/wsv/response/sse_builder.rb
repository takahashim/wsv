# frozen_string_literal: true

require_relative "sse_body"

module Wsv
  class Response
    # Builds a Server-Sent Events Response.
    #
    #   Wsv::Response.sse do |io|
    #     io.write("data: ping\n\n")
    #     io.flush
    #   end
    #
    # `Connection: close` is set by Response#write_to, so the body terminates
    # when the producer block returns. SSE clients (browsers) re-connect
    # automatically.
    class SseBuilder
      DEFAULT_HEADERS = {
        "Content-Type" => "text/event-stream; charset=utf-8",
        "Cache-Control" => "no-cache",
        # X-Accel-Buffering disables response buffering on reverse proxies
        # that respect it (nginx). Without this an SSE stream behind a
        # proxy would only deliver after the connection ended.
        "X-Accel-Buffering" => "no"
      }.freeze

      def initialize(status: 200, headers: {}, &producer)
        @status = status
        @headers = DEFAULT_HEADERS.merge(headers)
        @producer = producer
      end

      def build
        Response.new(
          status: @status,
          headers: @headers,
          body: SseBody.new(&@producer)
        )
      end
    end
  end
end
