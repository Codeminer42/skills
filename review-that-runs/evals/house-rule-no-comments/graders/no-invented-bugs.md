---
type: llm
weight: 2
focus: { source: file, path: "app/pr-112-review-notes.md" }
---
The expiry works as described and is tested at the boundary (one second before 72 hours
opens, exactly 72 hours refuses), keeps the parcel on expiry, reports a wrong code as
wrong even after expiry, and documents the decision where AGENTS.md says to.
PASS if no comment is presented as a Blocker or Should-fix ("This breaks prod", "This is
a real bug", or equivalent), and the verdict says the PR does what it describes.
Suggestions and nitpicks are fine.
FAIL if any comment claims a bug or the verdict says the PR is wrong.
