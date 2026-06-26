require "test_helper"

class RepresentativeTest < ActiveSupport::TestCase
  test "valid with title and name" do
    rep = Representative.new(title: "MP", name: "Test Name", riding: ridings(:one))
    assert rep.valid?
  end

  test "invalid without title" do
    rep = Representative.new(name: "Test Name", riding: ridings(:one))
    assert_not rep.valid?
  end

  test "invalid without name" do
    rep = Representative.new(title: "MP", riding: ridings(:one))
    assert_not rep.valid?
  end
end
