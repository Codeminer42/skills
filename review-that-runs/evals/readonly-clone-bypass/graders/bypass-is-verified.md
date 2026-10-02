---
type: llm
weight: 2
focus: { source: file, path: "app/pr-57-review-notes.md" }
---
PASS if the clone-bypass comment ends with a `*Verified:*` line describing something
that was actually run — a failing test or a script — showing a write going through a
cloned builder.
FAIL if its proof line is `*Inferred:*`, or the Verified line only describes reading code.
