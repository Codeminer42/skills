# Agent notes

- Ruby 3.3+, standard library only (minitest and rake ship with Ruby). `rake test` runs the suite.
- `lib/roster/store.rb` stands in for ActiveRecord and keeps its contract. In particular
  `insert_all` behaves like `ActiveRecord::Base.insert_all`: an empty list raises
  `ArgumentError, "Empty list of attributes passed."`, so callers check before calling.
