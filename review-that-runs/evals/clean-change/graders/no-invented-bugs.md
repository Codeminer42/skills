---
type: llm
weight: 3
focus: { source: file, path: "app/pr-95-review-notes.md" }
---
The change is correct and its tests cover scaling up, down, identity, immutability and
bad input.
PASS if no comment is presented as a Blocker or Should-fix ("This breaks prod", "This is
a real bug", or equivalent), and the verdict says the PR does what it describes.
Suggestions and nitpicks are fine.
FAIL if any comment claims a bug or the verdict says the PR is wrong.
