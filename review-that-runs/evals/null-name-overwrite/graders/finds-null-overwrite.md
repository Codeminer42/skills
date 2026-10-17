---
type: llm
weight: 3
focus: { source: file, path: "app/pr-63-review-notes.md" }
---
PASS if a comment says that the second loop in `binLabels` overwrites the layout's
product with the scan's, so a store-only product (scan `name: null`, which AGENTS.md
says happens) is labelled "Unnamed item" even though the layout knows its name. It must
be presented as a real bug (Should-fix or Blocker lead-in).
FAIL if the notes miss it or file it as a suggestion or nitpick.
