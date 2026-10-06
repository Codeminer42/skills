# Record architecture decisions with ADRs

## Status

Accepted

## Context

Decisions about this system get made in meetings, chat threads, and pull request comments. Months later nobody remembers why a library was picked, why a module is split the way it is, or why an obvious alternative was rejected. The team either rediscovers the reasons the hard way or reverses the decision without knowing it was deliberate.

Coding agents make this worse: they start every session with no memory of past discussions, so an unwritten decision doesn't exist for them. They will "fix" code that was shaped on purpose.

Commits and changelogs record *what* changed, not *why* one option won over the others.

## Decision

Record architecturally significant decisions as Architecture Decision Records in `<adr-dir>/`:

- One decision per file, named `YYYYMMDDHHMM-<decision-slug>.md`. Timestamps instead of sequence numbers so parallel branches don't collide.
- Each ADR follows `template.md`: Status, Context, Decision, Consequences.
- Statuses: Proposed, Accepted, Rejected, Deprecated, Superseded.
- ADRs are immutable. Only the status changes; a changed decision gets a new ADR that supersedes the old one.
- `README.md` in the folder indexes every ADR, and is regenerated from the files.
- The project's agent instructions tell agents to read the index before architectural changes and to propose an ADR when they make a significant decision.

Write an ADR when future developers will need the "why", or when the decision is architecturally significant, cross-team, or hard to reverse. Skip it for tiny, non-architectural, temporary, or already-documented decisions.

## Consequences

- New people and agents can learn why the system looks the way it does, and settled debates stay settled.
- Reviewers can check changes against accepted decisions.
- Writing an ADR adds a small cost to significant changes, and someone has to keep statuses current.
- The log is only useful if it stays selective. Trivial entries make it as hard to use as having none.
- Decisions made before this ADR are not recorded. They get ADRs when someone with the context writes them, not by guessing from the code.
