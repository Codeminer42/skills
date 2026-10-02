require "minitest/autorun"
require "lockers"

class LockerTest < Minitest::Test
  def setup
    @now = Time.utc(2026, 3, 2, 9, 0)
    @locker = Lockers::Locker.new(1, clock: -> { @now })
  end

  def test_drop_returns_a_six_digit_code
    assert_match(/\A\d{6}\z/, @locker.drop("box"))
  end

  def test_open_with_the_code_hands_over_the_parcel
    code = @locker.drop("box")
    assert_equal "box", @locker.open(code)
    refute @locker.parcel?
  end

  def test_open_with_a_wrong_code_keeps_the_parcel
    @locker.drop("box")
    assert_raises(Lockers::WrongCode) { @locker.open("000000x") }
    assert @locker.parcel?
  end

  def test_a_full_locker_refuses_a_second_parcel
    @locker.drop("box")
    assert_raises(ArgumentError) { @locker.drop("another") }
  end

  def test_code_still_works_just_before_72_hours
    code = @locker.drop("box")
    @now += Lockers::Locker::CODE_LIFETIME - 1
    assert_equal "box", @locker.open(code)
  end

  def test_code_expires_at_72_hours_and_the_parcel_stays
    code = @locker.drop("box")
    @now += Lockers::Locker::CODE_LIFETIME
    assert_raises(Lockers::ExpiredCode) { @locker.open(code) }
    assert @locker.parcel?
  end

  def test_a_wrong_code_after_expiry_is_still_just_wrong
    @locker.drop("box")
    @now += Lockers::Locker::CODE_LIFETIME * 2
    assert_raises(Lockers::WrongCode) { @locker.open("000000x") }
  end

  def test_an_empty_locker_has_no_expired_code
    refute @locker.code_expired?
  end
end
