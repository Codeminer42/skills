---
type: llm
weight: 3
focus: { source: file, path: "app/pr-71-review-notes.md" }
---
PASS if a comment says `importLoans` calls `insertMany('members', [])` when every loan's
member is already known, which throws `EmptyInsert` (AGENTS.md documents this) after the
loans were already inserted — so the common case of an export with no visiting members
crashes and leaves the loans half-imported. It must be presented as a real bug or worse.
FAIL if the notes miss it or file it as a suggestion or nitpick.
