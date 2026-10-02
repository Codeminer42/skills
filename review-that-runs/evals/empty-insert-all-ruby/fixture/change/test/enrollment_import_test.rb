require "minitest/autorun"
require "roster"

class EnrollmentImportTest < Minitest::Test
  def test_imports_bookings_and_adds_one_guest_per_unknown_member
    store = Roster::Store.new
    store.insert_all(:members, [{ id: 1, name: "Lia" }])

    result = Roster::EnrollmentImport.new(store).call([
      { "member_id" => 1, "session_id" => "tue-bouldering" },
      { "member_id" => 9, "session_id" => "tue-bouldering" },
      { "member_id" => 9, "session_id" => "thu-lead" }
    ])

    assert_equal({ enrollments: 3, guests: 1 }, result)
    assert_equal [{ id: 9, name: "Guest 9", guest: true }], store.where(:members, guest: true)
  end
end
