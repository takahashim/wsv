# frozen_string_literal: true

require_relative "access_log"
require_relative "deadline_reader"
require_relative "../request"
require_relative "../response"

module Wsv
  class Server
    # Owns a single accepted client socket. `serve` runs the request lifecycle
    # (parse → app → write → drain → close); `reject` writes 503 (when allowed)
    # and closes. Both share the safe-write / drain / close primitives so a
    # broken peer cannot leak a connection or mask errors.
    class Connection
      DRAIN_TIMEOUT = 5

      def initialize(client, err:, cors: nil, access_log: NullAccessLog.new)
        @client = client
        @err = err
        @cors = cors
        @access_log = access_log
        @remote_addr = remote_addr_of(client)
      end

      def serve(app, read_timeout:)
        request, response = process(app, read_timeout)
        write(response) if response
        log_access(request, response)
      ensure
        graceful_close
      end

      def reject(reply:)
        response = reply ? Response.text(503) : nil
        write(response) if response
        log_access(nil, response)
      ensure
        graceful_close
      end

      private

      def process(app, read_timeout)
        reader = DeadlineReader.new(@client, Time.now + read_timeout)
        request = Request.parse(reader)
        [request, build_response(app, request)]
      rescue Request::TooLarge => e
        [nil, Response.text(e.status_code)]
      rescue IO::TimeoutError
        [nil, Response.text(408)]
      rescue StandardError => e
        # Treat unmapped failures as connection-scoped and close with 400 rather
        # than letting one bad request path bring down the server.
        @err.puts "wsv: #{e.class}: #{e.message}"
        [nil, Response.text(400)]
      end

      def build_response(app, request)
        case request
        when :empty then nil
        when :malformed then Response.text(400)
        else app.call(request)
        end
      end

      # Connection is the sole place that adds ACAO / Vary headers, so every
      # response (App, parser errors, timeouts, the 503 rejection) gets them
      # uniformly when CORS is enabled.
      def write(response)
        return if @client.closed?

        finalize(response).write_to(@client)
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError
        nil
      end

      def finalize(response)
        @cors ? @cors.overlay(response) : response
      end

      def log_access(request, response)
        return unless response

        @access_log.record(
          remote_addr: @remote_addr,
          request: request.is_a?(Request) ? request : nil,
          status: response.status,
          bytes: response.bytesize
        )
      end

      def remote_addr_of(client)
        base = client.respond_to?(:io) ? client.io : client
        base.peeraddr(false)[3]
      rescue StandardError
        nil
      end

      def graceful_close
        return if @client.closed?

        drain_recv
      rescue StandardError
        nil
      ensure
        begin
          @client.close unless @client.closed?
        rescue StandardError
          nil
        end
      end

      def drain_recv
        deadline = Time.now + DRAIN_TIMEOUT
        loop do
          return if Time.now >= deadline

          chunk = @client.read_nonblock(8192, exception: false)
          case chunk
          when nil, :wait_writable
            # nil = EOF. :wait_writable can come back from SSLSocket during a
            # renegotiation (read needs an underlying write). Either way,
            # there's nothing more we can usefully drain right now.
            return
          when :wait_readable
            remaining = deadline - Time.now
            return if remaining <= 0
            return unless @client.wait_readable([remaining, 0.2].min)
          end
        end
      end
    end
  end
end
