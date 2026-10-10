require "minitest/autorun"
require "roster"

class StoreTest < Minitest::Test
  def test_insert_all_stores_rows
    store = Roster::Store.new
    assert_equal 2, store.insert_all(:members, [{ id: 1 }, { id: 2 }])
    assert_equal [{ id: 2 }], store.where(:members, id: 2)
  end

  def test_insert_all_refuses_an_empty_list_like_active_record
    error = assert_raises(ArgumentError) { Roster::Store.new.insert_all(:members, []) }
    assert_equal "Empty list of attributes passed.", error.message
  end
end
