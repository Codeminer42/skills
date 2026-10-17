module Roster
  # In-memory stand-in for the ActiveRecord models. Same method names, same errors.
  class Store
    attr_reader :members, :enrollments

    def initialize
      @members = []
      @enrollments = []
    end

    def insert_all(table, rows)
      raise ArgumentError, "Empty list of attributes passed." if rows.empty?

      public_send(table).concat(rows)
      rows.size
    end

    def where(table, **conditions)
      public_send(table).select { |row| conditions.all? { |key, value| row[key] == value } }
    end
  end
end
