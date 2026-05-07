# frozen_string_literal: true

require_relative "test_helper"

class CLITest < Minitest::Test
  def test_defaults
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        options = Wsv::CLI.new([]).parse_options([])

        assert_equal "127.0.0.1", options[:host]
        assert_equal 8000, options[:port]
        assert_equal File.realpath(dir), options[:directory]
      end
    end
  end

  def test_host_port_and_directory
    Dir.mktmpdir do |dir|
      options = Wsv::CLI.new([]).parse_options(["-h", "127.0.0.1", "-p", "3000", dir])

      assert_equal "127.0.0.1", options[:host]
      assert_equal 3000, options[:port]
      assert_equal dir, options[:directory]
    end
  end

  def test_long_host_port_and_directory
    Dir.mktmpdir do |dir|
      options = Wsv::CLI.new([]).parse_options(["--host", "localhost", "--port", "4567", dir])

      assert_equal "localhost", options[:host]
      assert_equal 4567, options[:port]
      assert_equal dir, options[:directory]
    end
  end

  def test_help
    out = StringIO.new
    code = Wsv::CLI.new(["--help"], out: out).run

    assert_equal 0, code
    assert_includes out.string, "Usage: wsv"
    assert_includes out.string, "--host HOST"
    assert_includes out.string, "Examples:"
    assert_includes out.string, "wsv _site"
  end

  def test_version
    out = StringIO.new
    code = Wsv::CLI.new(["--version"], out: out).run

    assert_equal 0, code
    assert_equal "#{Wsv::VERSION}\n", out.string
  end

  def test_invalid_port
    err = StringIO.new
    code = Wsv::CLI.new(["-p", "0"], err: err).run

    assert_equal 1, code
    assert_includes err.string, "port must be between 1 and 65535"
  end

  def test_missing_directory
    err = StringIO.new
    missing = File.join(Dir.tmpdir, "wsv-missing-#{Time.now.to_i}-#{$$}")
    code = Wsv::CLI.new([missing], err: err).run

    assert_equal 1, code
    assert_includes err.string, "directory does not exist"
  end

  def test_tls_flag_parses
    Dir.mktmpdir do |dir|
      options = Wsv::CLI.new([]).parse_options(["--tls", dir])

      assert options[:tls]
    end
  end

  def test_cert_without_key_errors
    err = StringIO.new
    Dir.mktmpdir do |dir|
      code = Wsv::CLI.new(["--cert", "/nonexistent/cert.pem", dir], err: err).run

      assert_equal 1, code
      assert_includes err.string, "must be provided together"
    end
  end

  def test_cert_and_key_parses
    Dir.mktmpdir do |dir|
      options = Wsv::CLI.new([]).parse_options(["--cert", "a.pem", "--key", "b.pem", dir])

      assert_equal "a.pem", options[:cert]
      assert_equal "b.pem", options[:key]
    end
  end

  def test_spa_flag_parses
    Dir.mktmpdir do |dir|
      options = Wsv::CLI.new([]).parse_options(["--spa", dir])

      assert options[:spa]
      assert_equal dir, options[:directory]
    end
  end

  def test_cors_flag_parses
    Dir.mktmpdir do |dir|
      options = Wsv::CLI.new([]).parse_options(["--cors", dir])

      assert options[:cors]
      assert_equal dir, options[:directory]
    end
  end

  def test_cors_default_off
    Dir.mktmpdir do |dir|
      options = Wsv::CLI.new([]).parse_options([dir])

      refute options[:cors]
    end
  end

  def test_open_flag_parses
    Dir.mktmpdir do |dir|
      options = Wsv::CLI.new([]).parse_options(["--open", dir])

      assert options[:open]
      assert_equal dir, options[:directory]
    end
  end
end
