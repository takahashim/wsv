# frozen_string_literal: true

require "net/http"
require "socket"
require_relative "test_helper"

# Covers two related extension points:
#
#   * `Wsv::Server.new(app:)` — DI a custom request handler
#   * `Wsv::Response.sse { |io| ... }` — long-lived Server-Sent Events responses
class CustomAppTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @server = nil
    @thread = nil
  end

  def teardown
    @server&.stop
    @thread&.join(2)
    FileUtils.remove_entry(@dir)
  end

  def test_custom_app_handles_requests_in_place_of_default
    app = Class.new do
      def call(_request)
        Wsv::Response.new(
          status: 200,
          headers: { "Content-Type" => "text/plain", "Content-Length" => "8" },
          body: "from-app"
        )
      end
    end.new

    start_server(app: app)
    response = get("/anything")

    assert_equal "200", response.code
    assert_equal "from-app", response.body
  end

  def test_sse_response_delivers_chunks_in_order
    chunks = ["data: one\n\n", "data: two\n\n", "data: three\n\n"]
    app = Class.new do
      define_method(:call) do |_request|
        Wsv::Response.sse do |io|
          chunks.each do |c|
            io.write(c)
            io.flush
          end
        end
      end
    end.new

    start_server(app: app)
    body = read_full_body("/events")

    chunks.each { |c| assert_includes body, c }
    assert_operator body.index(chunks[0]), :<, body.index(chunks[1])
    assert_operator body.index(chunks[1]), :<, body.index(chunks[2])
  end

  def test_sse_response_uses_event_stream_content_type
    app = Class.new do
      def call(_request)
        Wsv::Response.sse { |io| io.write("data: hi\n\n") }
      end
    end.new

    start_server(app: app)
    response = get("/stream")

    assert_equal "200", response.code
    assert_match %r{text/event-stream}, response["content-type"]
    refute response["content-length"], "sse must not advertise Content-Length"
  end

  private

  def start_server(app:)
    @server = Wsv::Server.new(
      host: "127.0.0.1",
      port: free_port,
      root: @dir,
      out: StringIO.new,
      err: StringIO.new,
      app: app
    )
    @thread = Thread.new { @server.start }
    wait_until_ready
  end

  def free_port
    s = TCPServer.new("127.0.0.1", 0)
    s.addr[1]
  ensure
    s&.close
  end

  def wait_until_ready
    deadline = Time.now + 2
    loop do
      TCPSocket.open("127.0.0.1", @server.port).close
      break
    rescue Errno::ECONNREFUSED
      raise if Time.now >= deadline

      sleep 0.01
    end
  end

  def get(path)
    Net::HTTP.get_response(URI("http://127.0.0.1:#{@server.port}#{path}"))
  end

  # Read until the server closes the connection (streaming responses
  # omit Content-Length so Net::HTTP would still read-to-EOF, but for
  # clarity we use a raw socket here).
  def read_full_body(path)
    socket = TCPSocket.open("127.0.0.1", @server.port)
    socket.write("GET #{path} HTTP/1.1\r\nHost: localhost\r\n\r\n")
    raw = socket.read
    header_end = raw.index("\r\n\r\n")
    raw[(header_end + 4)..]
  ensure
    socket&.close
  end
end
