
### The ADR check

`<check>` checks the records, the index, the links in every file agents read, and every place code or docs cite a record. CI runs it on every pull request; run it before pushing.

- `<new>` creates a record from the template and adds it to the index.
- `<index>` regenerates the index after a status change.
- Cite a record by its file name without `.md` (`YYYYMMDDHHMM-<decision-slug>`), never by a sequence number. The check fails a citation that names no record. It warns on one that names a superseded or deprecated record, since that comment now points at a decision that no longer stands.
- Once a record is merged, the check allows changes to its Status section only, and only forward:
  - Proposed → Accepted or Rejected
  - Accepted → Deprecated or Superseded
  - Deprecated → Superseded
