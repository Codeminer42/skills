---
name: adr-setup
description: Set up Architecture Decision Records (ADRs) in a repository. Creates the ADR folder, the template, an index README, a first ADR recording the adoption, and adds a section to AGENTS.md or CLAUDE.md so agents check existing decisions and record new ones while they work. Does nothing if the repo already uses ADRs in any form. Use when asked to set up ADRs, start using architecture decision records, add a decision log, or bootstrap docs/adr in a project.
license: MIT
metadata:
  author: talyssonoc
  version: "1.0"
---

# ADR setup

Bootstraps a decision log in the current repository. This skill sets the structure up once; the agent-instructions section it installs is what keeps ADRs being written afterwards.

An agent starts every session without memory of past discussions. If a decision isn't written down, the agent doesn't know it exists and may "improve" the code by undoing it. The setup below makes accepted decisions part of the context every session reads.

## Conventions this setup installs

- **One decision per file** in a dedicated folder (default `docs/adr/`).
- **File name**: `YYYYMMDDHHMM-<decision-slug>.md`, like a migration. The slug names the *decision*, not the topic: `use-postgresql-as-primary-database`, not `database`.
- **Timestamps, not sequence numbers.** `0001-`, `0002-` collide when two branches add an ADR at the same time. Timestamps don't, and they keep the folder sorted.
- **Statuses**: Proposed, Accepted, Rejected, Deprecated, Superseded (always with a link to the replacing ADR).
- **Immutable.** Once written, only the status changes. A changed decision gets a new ADR that supersedes the old one.
- **Index**: `README.md` in the ADR folder, with a table of date, linked decision, and status. Agents regenerate it.

## Flow

Track progress with these steps, in order.

### 1. Detect an existing setup

Look for any form of ADRs before creating anything (skip `node_modules`, `vendor` and other dependency folders):

- folders: `docs/adr`, `doc/adr`, `docs/adrs`, `adr`, `adrs`, `docs/decisions`, `doc/decisions`, `docs/architecture/decisions`, `architecture/decisions`
- tool config: `.adr-dir` (adr-tools), `.log4brains.yml` (log4brains)
- files named like `*-record-architecture-decisions.md`, `adr-*.md` or `*-adr.md` (case-insensitive)
- markdown files that have both a Status and a Decision heading (Nygard, MADR and similar templates)

**If anything turns up, stop here. This skill is a no-op on such a repo.** Tell the user the project already uses ADRs, and say where (folder, tool, naming scheme), then finish without creating or changing any file. Don't recommend migrating, renaming, adopting this skill's conventions, or dropping their tooling: the team's existing practice wins.

Also grep `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md` and the docs for "ADR" or "decision record". A mention alone, with no records on disk, means the practice was intended but never set up: **don't stop**, continue the setup and carry what the mention says into step 2.

### 2. Pick the folder

If a mention found in step 1 names a folder for ADRs, use it. Otherwise default to `docs/adr/`. Use `doc/adr/` only if the repo already has a `doc/` folder and no `docs/`. Below, `<adr-dir>` means the chosen path relative to the repo root.

### 3. Write the template

Copy [assets/template.md](assets/template.md) to `<adr-dir>/template.md` unchanged.

### 4. Write the first ADR

Get the timestamp with `date +%Y%m%d%H%M` and copy [assets/first-adr.md](assets/first-adr.md) to `<adr-dir>/<timestamp>-record-architecture-decisions-with-adrs.md`. Replace `<adr-dir>` inside it. Status is Accepted: setting the log up *is* the decision being taken.

### 5. Write the index README

Copy [assets/README.md](assets/README.md) to `<adr-dir>/README.md`. Fill the index table with one row per ADR in the folder, oldest first, excluding `README.md` and `template.md`. The date column comes from the file name's timestamp (`YYYY-MM-DD`).

### 6. Add the agent-instructions section

Pick the target file:

| Repo has | Edit |
|---|---|
| `CLAUDE.md` that imports `@AGENTS.md` | `AGENTS.md` |
| only `AGENTS.md` | `AGENTS.md` |
| only `CLAUDE.md` | `CLAUDE.md` |
| both, no import between them | ask the user which one (or both) |
| neither | ask the user which file to create; don't pick one |

Append the contents of [assets/agent-instructions.md](assets/agent-instructions.md), replacing every `<adr-dir>`. If the file already mentions ADRs (step 1), leave that text as is and append the section anyway.
Also check for other agent instruction files the project keeps (`.github/copilot-instructions.md`, `.cursor/rules/`, `GEMINI.md`). Mention them in the report; don't edit them unasked.

### 7. Report

List every file created or changed and anything skipped and why. Do not commit.

## Gotchas

- `date` uses local time. That's fine: the timestamp only orders files and avoids collisions, it is not an audit trail.
- Do not seed ADRs for decisions you infer from the code ("uses PostgreSQL", "uses React"). Without the real context and alternatives, they are guesses dressed as records. Offer to write them with the user instead.
- Do not add a status column value that isn't in the ADR file. The index mirrors the files; the files are the source of truth.
- A superseded ADR keeps its file. Its status line becomes `Superseded by [<new title>](./<new-file>.md)`, and nothing else in it changes.
- The index is regenerated from the files, not hand-merged. When two branches both add rows, resolve the conflict by regenerating.

## Further reading

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions), Michael Nygard
- [Architecture Decision Records](https://architecture-decision-record.github.io/): overview, templates, examples
- [ADR writing guide](https://github.com/architecture-decision-record/architecture-decision-record/blob/main/skills/architecture-decision-record-skill/reference/writing-guide.md)
