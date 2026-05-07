# frozen_string_literal: true

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

      def initialize(client, err:)
        @client = client
        @err = err
      end

      def serve(app, read_timeout:)
        reader = DeadlineReader.new(@client, Time.now + read_timeout)
        request = Request.parse(reader)
        case request
        when :empty
          nil
        when :malformed
          write(Response.text(400))
        else
          write(app.call(request))
        end
      rescue Request::TooLarge => e
        write(Response.text(e.status_code))
      rescue IO::TimeoutError
        write(Response.text(408))
      rescue StandardError => e
        # Treat unmapped failures as connection-scoped and close with 400 rather
        # than letting one bad request path bring down the server.
        @err.puts "wsv: #{e.class}: #{e.message}"
        write(Response.text(400))
      ensure
        graceful_close
      end

      def reject(reply:)
        write(Response.text(503)) if reply
      ensure
        graceful_close
      end

      private

      def write(response)
        return if @client.closed?

        response.write_to(@client)
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError
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
