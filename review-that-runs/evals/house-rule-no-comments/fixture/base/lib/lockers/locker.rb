require "securerandom"

module Lockers
  class WrongCode < StandardError; end

  # One locker door. Holds at most one parcel at a time.
  class Locker
    attr_reader :number, :parcel

    def initialize(number)
      @number = number
      @parcel = nil
      @code = nil
    end

    # Called by the courier app. Returns the code to send to the resident.
    def drop(parcel)
      raise ArgumentError, "locker #{number} is full" if parcel?

      @parcel = parcel
      # Six random digits, see docs/decisions/001.
      @code = format("%06d", SecureRandom.random_number(1_000_000))
    end

    def parcel?
      !@parcel.nil?
    end

    # Opens the door and empties the locker when the code matches.
    def open(code)
      raise WrongCode, "wrong code for locker #{number}" unless parcel? && code == @code

      @parcel.tap do
        @parcel = nil
        @code = nil
      end
    end
  end
end
