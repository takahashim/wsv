# frozen_string_literal: true

module Wsv
  class Server
    # Caps in-flight connections at `max`. `try_spawn` runs the block in a new
    # thread when capacity is available and returns true; otherwise returns
    # false so the caller can reject the client.
    class ConnectionThrottle
      def initialize(max:, err:)
        @max = max
        @err = err
        @mutex = Mutex.new
        @active = 0
      end

      def try_spawn(&block)
        return false unless reserve_slot

        begin
          Thread.new do
            Thread.current.report_on_exception = false
            block.call
          ensure
            release_slot
          end
          true
        rescue ThreadError => e
          @err.puts "wsv: thread error: #{e.message}"
          release_slot
          false
        end
      end

      private

      def reserve_slot
        @mutex.synchronize do
          next false if @active >= @max

          @active += 1
          true
        end
      end

      def release_slot
        @mutex.synchronize { @active -= 1 }
      end
    end
  end
end
