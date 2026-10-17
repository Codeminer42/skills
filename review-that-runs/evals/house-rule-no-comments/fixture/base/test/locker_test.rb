require "minitest/autorun"
require "lockers"

class LockerTest < Minitest::Test
  def test_drop_returns_a_six_digit_code
    assert_match(/\A\d{6}\z/, Lockers::Locker.new(1).drop("box"))
  end

  def test_open_with_the_code_hands_over_the_parcel
    locker = Lockers::Locker.new(1)
    code = locker.drop("box")
    assert_equal "box", locker.open(code)
    refute locker.parcel?
  end

  def test_open_with_a_wrong_code_keeps_the_parcel
    locker = Lockers::Locker.new(1)
    locker.drop("box")
    assert_raises(Lockers::WrongCode) { locker.open("000000x") }
    assert locker.parcel?
  end

  def test_a_full_locker_refuses_a_second_parcel
    locker = Lockers::Locker.new(1)
    locker.drop("box")
    assert_raises(ArgumentError) { locker.drop("another") }
  end
end
