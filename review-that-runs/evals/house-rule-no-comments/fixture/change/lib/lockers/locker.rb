require "securerandom"

module Lockers
  class WrongCode < StandardError; end
  class ExpiredCode < StandardError; end

  class Locker
    CODE_LIFETIME = 72 * 60 * 60

    attr_reader :number, :parcel

    def initialize(number, clock: -> { Time.now })
      @number = number
      @clock = clock
      @parcel = nil
      @code = nil
      @dropped_at = nil
    end

    def drop(parcel)
      raise ArgumentError, "locker #{number} is full" if parcel?

      @parcel = parcel
      @dropped_at = @clock.call
      @code = format("%06d", SecureRandom.random_number(1_000_000))
    end

    def parcel?
      !@parcel.nil?
    end

    def code_expired?
      parcel? && @clock.call - @dropped_at >= CODE_LIFETIME
    end

    def open(code)
      raise WrongCode, "wrong code for locker #{number}" unless parcel? && code == @code
      raise ExpiredCode, "code for locker #{number} has expired; ask the front desk" if code_expired?

      @parcel.tap do
        @parcel = nil
        @code = nil
        @dropped_at = nil
      end
    end
  end
end
