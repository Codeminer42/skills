# Architecture Decision Records

This folder is the project's decision log. Each file records one architectural decision: the context that led to it, the decision itself, and its consequences. Commits record *what* changed; ADRs record *why*.

## When to write one

Write an ADR when:

- future developers will need to understand the "why" behind what's being done;
- the decision is architecturally significant, cross-team, or hard to reverse.

Skip it when:

- the decision isn't architectural, or is tiny (minimal-risk, self-contained, single-developer);
- it's already fully covered by an existing standard, policy, or document;
- it's temporary: a workaround, a proof of concept, or an experiment.

An ADR is not a changelog and not a feature spec.

## How to add one

1. Copy `template.md` to `YYYYMMDDHHMM-<decision-slug>.md` (`date +%Y%m%d%H%M`).
2. Name the decision, not the topic: `use-postgresql-as-primary-database`, not `database`. If the name needs "and", split it into two ADRs.
3. Fill in Context, Decision, and Consequences. Start with status Proposed.
4. Add a row to the index below.

## Statuses

| Status | Meaning |
| --- | --- |
| **Proposed** | Under discussion, not yet agreed. |
| **Accepted** | Agreed and in effect. |
| **Rejected** | Considered and turned down. Kept so nobody proposes it again blindly. |
| **Deprecated** | No longer applies, with nothing replacing it. |
| **Superseded** | Replaced by a newer decision. Always links to the ADR that replaced it. |

## ADRs are immutable

Once written, an ADR is not edited. Only its status changes. When a decision changes, write a new ADR that explains the new context, and set the old one's status to `Superseded by [title](./file.md)`. Older code may still follow the earlier decision; the log explains why.

## Index

Regenerate this table from the files rather than editing it by hand:

> Read every ADR in this folder (except `README.md` and `template.md`) and regenerate the table below with the date, a link to each decision, and its current status. For superseded ADRs, link to the ADR that replaced them.

| Date | Decision | Status |
| --- | --- | --- |
