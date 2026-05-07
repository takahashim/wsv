# frozen_string_literal: true

require_relative "test_helper"

class RangeRequestTest < Minitest::Test
  def test_nil_header_is_full
    result = Wsv::RangeRequest.parse(nil, 100)

    assert_predicate result, :full?
  end

  def test_empty_header_is_full
    result = Wsv::RangeRequest.parse("", 100)

    assert_predicate result, :full?
  end

  def test_unparseable_syntax_is_full
    # Per RFC 7233 an unparseable Range is treated as if absent.
    result = Wsv::RangeRequest.parse("garbage", 100)

    assert_predicate result, :full?
  end

  def test_empty_range_is_full
    # `bytes=-` matches the regex but yields no bounds; treat as absent.
    result = Wsv::RangeRequest.parse("bytes=-", 100)

    assert_predicate result, :full?
  end

  def test_bounded_range
    result = Wsv::RangeRequest.parse("bytes=2-5", 100)

    assert_predicate result, :partial?
    assert_equal 2..5, result.bounds
  end

  def test_open_range
    result = Wsv::RangeRequest.parse("bytes=5-", 10)

    assert_predicate result, :partial?
    assert_equal 5..9, result.bounds
  end

  def test_suffix_range
    result = Wsv::RangeRequest.parse("bytes=-3", 10)

    assert_predicate result, :partial?
    assert_equal 7..9, result.bounds
  end

  def test_suffix_larger_than_file_clamps_to_zero
    result = Wsv::RangeRequest.parse("bytes=-99", 10)

    assert_predicate result, :partial?
    assert_equal 0..9, result.bounds
  end

  def test_bounded_last_past_file_clamps_to_end
    result = Wsv::RangeRequest.parse("bytes=5-99", 10)

    assert_predicate result, :partial?
    assert_equal 5..9, result.bounds
  end

  def test_zero_byte_suffix_is_unsatisfiable
    result = Wsv::RangeRequest.parse("bytes=-0", 10)

    assert_predicate result, :unsatisfiable?
  end

  def test_suffix_against_empty_file_is_unsatisfiable
    result = Wsv::RangeRequest.parse("bytes=-3", 0)

    assert_predicate result, :unsatisfiable?
  end

  def test_open_range_past_file_is_unsatisfiable
    result = Wsv::RangeRequest.parse("bytes=10-", 5)

    assert_predicate result, :unsatisfiable?
  end

  def test_bounded_first_past_file_is_unsatisfiable
    result = Wsv::RangeRequest.parse("bytes=10-20", 5)

    assert_predicate result, :unsatisfiable?
  end

  def test_inverted_bounded_range_is_unsatisfiable
    result = Wsv::RangeRequest.parse("bytes=5-3", 100)

    assert_predicate result, :unsatisfiable?
  end

  def test_bounded_range_at_exact_file_boundary
    result = Wsv::RangeRequest.parse("bytes=0-9", 10)

    assert_predicate result, :partial?
    assert_equal(0..9, result.bounds)
  end

  def test_suffix_range_equal_to_file_size
    result = Wsv::RangeRequest.parse("bytes=-10", 10)

    assert_predicate result, :partial?
    assert_equal(0..9, result.bounds)
  end

  def test_single_byte_range_at_last_position
    result = Wsv::RangeRequest.parse("bytes=9-9", 10)

    assert_predicate result, :partial?
    assert_equal(9..9, result.bounds)
  end

  def test_multipart_range_is_full
    # `bytes=0-2,5-7` doesn't match the single-range regex; treat as absent.
    result = Wsv::RangeRequest.parse("bytes=0-2,5-7", 100)

    assert_predicate result, :full?
  end
end
