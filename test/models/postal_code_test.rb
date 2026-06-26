require "test_helper"

class PostalCodeTest < ActiveSupport::TestCase
  setup do
    @riding = ridings(:one)
  end

  test "valid with standard format no space" do
    pc = PostalCode.new(code: "K1P1A4", riding: @riding)
    assert pc.valid?
  end

  test "valid with space in code" do
    pc = PostalCode.new(code: "K1P 1A4", riding: @riding)
    assert pc.valid?
  end

  test "normalizes lowercase to uppercase" do
    pc = PostalCode.create!(code: "k1p1a4", riding: @riding)
    assert_equal "K1P 1A4", pc.code
  end

  test "invalid with non-Canadian format" do
    pc = PostalCode.new(code: "XXXXXX", riding: @riding)
    assert_not pc.valid?
    assert_includes pc.errors[:code], "must be a valid Canadian postal code (e.g. K1A 0A6)"
  end

  test "invalid with numeric code" do
    pc = PostalCode.new(code: "123456", riding: @riding)
    assert_not pc.valid?
  end

  test "invalid with empty code" do
    pc = PostalCode.new(code: "", riding: @riding)
    assert_not pc.valid?
  end

  test "uniqueness is enforced" do
    PostalCode.create!(code: "H0H0H0", riding: @riding)
    dup = PostalCode.new(code: "H0H0H0", riding: @riding)
    assert_not dup.valid?
    assert_includes dup.errors[:code], "has already been taken"
  end
end
