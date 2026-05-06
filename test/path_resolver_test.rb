# frozen_string_literal: true

require_relative "test_helper"

class PathResolverTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @root = File.realpath(@dir)
    @resolver = Wsv::PathResolver.new(@root)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_resolves_existing_file
    path = File.join(@dir, "hello.txt")
    File.write(path, "hi")

    result = @resolver.resolve("/hello.txt")

    assert result.file?
    assert_equal File.realpath(path), result.file
  end

  def test_returns_404_for_missing_file
    result = @resolver.resolve("/nope.txt")

    assert result.error?
    assert_equal 404, result.status
  end

  def test_redirects_directory_without_trailing_slash
    FileUtils.mkdir_p(File.join(@dir, "docs"))
    File.write(File.join(@dir, "docs", "index.html"), "x")

    result = @resolver.resolve("/docs")

    assert result.redirect?
  end

  def test_serves_index_for_directory_with_trailing_slash
    FileUtils.mkdir_p(File.join(@dir, "docs"))
    index = File.join(@dir, "docs", "index.html")
    File.write(index, "x")

    result = @resolver.resolve("/docs/")

    assert result.file?
    assert_equal File.realpath(index), result.file
  end

  def test_directory_without_index_is_404
    FileUtils.mkdir_p(File.join(@dir, "assets"))

    result = @resolver.resolve("/assets/")

    assert result.error?
    assert_equal 404, result.status
  end

  def test_rejects_path_traversal
    result = @resolver.resolve("/../etc/passwd")

    assert result.error?
    assert_equal 403, result.status
  end

  def test_rejects_dotfile_at_root
    File.write(File.join(@dir, ".env"), "secret")

    result = @resolver.resolve("/.env")

    assert result.error?
    assert_equal 403, result.status
  end

  def test_rejects_dot_directory
    FileUtils.mkdir_p(File.join(@dir, ".git"))
    File.write(File.join(@dir, ".git", "config"), "x")

    result = @resolver.resolve("/.git/config")

    assert result.error?
    assert_equal 403, result.status
  end

  def test_rejects_dotfile_in_subdir
    FileUtils.mkdir_p(File.join(@dir, "sub"))
    File.write(File.join(@dir, "sub", ".secret"), "x")

    result = @resolver.resolve("/sub/.secret")

    assert result.error?
    assert_equal 403, result.status
  end

  def test_rejects_url_encoded_traversal
    result = @resolver.resolve("/%2e%2e/etc/passwd")

    assert result.error?
    assert_equal 403, result.status
  end

  def test_rejects_url_encoded_dotfile
    File.write(File.join(@dir, ".env"), "secret")

    result = @resolver.resolve("/%2eenv")

    assert result.error?
    assert_equal 403, result.status
  end

  def test_preserves_literal_plus_in_path
    File.write(File.join(@dir, "foo+bar.txt"), "x")

    result = @resolver.resolve("/foo+bar.txt")

    assert result.file?
    assert_equal File.realpath(File.join(@dir, "foo+bar.txt")), result.file
  end

  def test_returns_400_for_invalid_uri
    result = @resolver.resolve("http://[invalid")

    assert result.error?
    assert_equal 400, result.status
  end

  def test_rejects_symlink_to_dotfile
    File.write(File.join(@dir, ".env"), "secret")
    File.symlink(".env", File.join(@dir, "config"))

    result = @resolver.resolve("/config")

    assert result.error?
    assert_equal 403, result.status
  end

  def test_rejects_symlink_to_dot_directory
    FileUtils.mkdir_p(File.join(@dir, ".git"))
    File.write(File.join(@dir, ".git", "HEAD"), "ref")
    File.symlink(".git", File.join(@dir, "gitstuff"))

    result = @resolver.resolve("/gitstuff/HEAD")

    assert result.error?
    assert_equal 403, result.status
  end

  def test_allows_internal_symlink_to_regular_file
    File.write(File.join(@dir, "real.txt"), "data")
    File.symlink("real.txt", File.join(@dir, "alias.txt"))

    result = @resolver.resolve("/alias.txt")

    assert result.file?
    assert_equal File.realpath(File.join(@dir, "real.txt")), result.file
  end

  def test_handles_symlink_loop
    File.symlink("b", File.join(@dir, "a"))
    File.symlink("a", File.join(@dir, "b"))

    result = @resolver.resolve("/a")

    assert result.error?
    assert_equal 404, result.status
  end

  def test_rejects_symlink_outside_root
    outside = File.join(File.dirname(@dir), "wsv-outside-#{$$}")
    File.write(outside, "leaked")
    File.symlink(outside, File.join(@dir, "link"))

    result = @resolver.resolve("/link")

    assert result.error?
    assert_equal 403, result.status
  ensure
    FileUtils.rm_f(outside) if outside
  end

end
