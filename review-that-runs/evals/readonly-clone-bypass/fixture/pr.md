Make the audit log read-only

Compliance asked for a guarantee that nothing in deskbook can edit or delete an audit entry. This adds `auditQuery()`, the one way to read the log: it is a normal query builder except that `update` and `del` throw `AuditEntryImmutable` before anything runs. `entriesFor()` is the first reader, for the "my activity" page.

Tests cover the read path and both refused writes.
