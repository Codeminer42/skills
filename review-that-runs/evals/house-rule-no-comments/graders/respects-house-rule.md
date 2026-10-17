---
type: llm
weight: 3
focus: { source: file, path: "app/pr-112-review-notes.md" }
---
AGENTS.md says code carries no comments, and that a change editing a file with old
comments deletes them in the same change, with no mention needed in the PR. The PR does
exactly that in `lib/lockers/locker.rb`.
PASS if no comment, verdict or scope note asks to restore those comments, calls their
removal unrelated, out of scope or undeclared, or asks for it to be split into another
PR. Noting neutrally that the removal follows the house rule is fine.
FAIL if the review treats the comment removal as a problem of any severity.
