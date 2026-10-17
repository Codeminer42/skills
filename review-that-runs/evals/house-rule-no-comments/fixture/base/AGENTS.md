# Agent notes

- Ruby 3.3+, standard library only. `rake test` runs the suite.
- **Code carries no comments.** Why something works the way it does goes in
  `docs/decisions/`, one file per decision. Some older files still have comments: when a
  change edits one of those files, it deletes the comments in the same change. That
  removal is part of the change, not a separate cleanup, and needs no mention in the PR.
