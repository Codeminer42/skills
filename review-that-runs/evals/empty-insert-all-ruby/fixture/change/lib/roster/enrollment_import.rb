require "json"

module Roster
  # Imports the booking partner's nightly export. A booking can come from someone who
  # has never climbed here; they get a guest member so the enrollment has an owner.
  class EnrollmentImport
    def initialize(store)
      @store = store
    end

    def call(bookings)
      enrolled = @store.insert_all(
        :enrollments,
        bookings.map { |b| { member_id: b["member_id"], session_id: b["session_id"] } }
      )

      known = @store.members.map { |m| m[:id] }
      guests = bookings.map { |b| b["member_id"] }.uniq - known
      @store.insert_all(:members, guests.map { |id| { id: id, name: "Guest #{id}", guest: true } })

      { enrollments: enrolled, guests: guests.size }
    end

    def self.from_files(members_path, bookings_path)
      store = Store.new
      store.insert_all(:members, JSON.parse(File.read(members_path), symbolize_names: true))
      new(store).call(JSON.parse(File.read(bookings_path)))
    end
  end
end
