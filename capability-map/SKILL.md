---
name: capability-map
description: Draft a capability map for a repository, a single page that maps the client's domain. It lists every capability with what it owns, the words it uses, its contracts, who acts on it, what it is NOT, where its code lives, the ADRs that bind it and its state, grouped by context. Builds the draft from the client's documents, meeting notes and glossary as well as the code. Keeps the client's words over the code's, records disagreements instead of settling them, and ends with a list of questions for the team and the client. Adds a section with a generated capability table to AGENTS.md or CLAUDE.md, so agents read an entry before changing its code. Offers a check (one bash script) that fails CI on a stale table, a broken entry, or a glossary term no capability speaks. Commits nothing. Use when asked to map the domain, write a capability map, define the ubiquitous language or bounded contexts for agents, or stop agents inventing names for the client's concepts.
license: MIT
metadata:
  author: geeksilva97
  version: "1.0"
---

# Capability map

Drafts `docs/capability-map.md`, a single page that maps the domain of a project. It lists every capability the system has, what each one owns, which words it uses, and what it is **not**. People and agents read it to answer "what lives here, and what do we call it?" before opening the code.

An agent doesn't know the client's words. It fills the gap with the most common name it has seen, such as `Cart`, `Asset` or `User`, and that name spreads through the code, the API and the screens. The map gives every session the client's words, and the boundaries between the parts of the system.

## This skill drafts; people decide

The two most important things in a capability map come from people, not from the code:

- **the language:** the words the client uses for its own business;
- **the "Is not" lines:** where one capability ends and the next begins, as the team understands it.

So the skill does not hand over a finished map. It hands over a **draft and a list of questions**. Every word the code and the documents disagree on, and every boundary the code doesn't make clear, goes into the questions instead of being settled by the agent.

The skill also:

- **fixes nothing.** Gaps found while mapping (permissions nobody checks, wrong glossary entries) are recorded, not fixed;
- **doesn't commit.**

## Conventions the map follows

- **One page**, with a short intro that says what it is and where words and decisions are defined.
- **Contexts** are `# ` headings: the large areas of the business, such as _Tenancy & access_, _Fleet_ or _Sales_, each with one sentence under it. Three to six is typical.
- **Capabilities** are `## ` headings with a lowercase-kebab id (`access-control`, `manual-review`). The id is also the anchor agents link to.
- **Every entry has the same fields, in the same order, one line each:**

| Field         | What it says                                                                                    |
| ------------- | ----------------------------------------------------------------------------------------------- |
| **One line**  | What the capability is, in one sentence a client would recognize.                               |
| **Language**  | The words it uses, in the client's terms. Name the states a thing moves through.                |
| **Owns**      | The data it owns and the rules it enforces on that data.                                        |
| **Contracts** | What others use: routes, events, emails, jobs.                                                  |
| **Who acts**  | Who can use it, by role or permission, and what checks it. Say when a permission is declared but not checked. |
| **Is not**    | What it doesn't do, and which capability does, by id.                                           |
| **Lives in**  | Where its code is, across every app.                                                            |
| **Decisions** | The ADRs in effect that a change here must respect, by ID, each with a few words. The most binding ten at most; the ADR index holds the rest. |
| **State**     | Built, partial or planned, and the gaps found while mapping it.                                 |

- **A capability spans apps.** The map follows the domain, not the folders. One capability's entry lists its backend, frontend and admin code together.
- **Closing sections**, in this order: **Declared, not built** (permissions, flags or concepts that exist and nothing implements), **Where the words still disagree** (synonyms and overloaded terms), **Seams worth knowing** (one rule split across capabilities), and a short **How to keep this page true** footer.
- **The glossary defines words. The map says which capability speaks them.** If the project has a glossary, don't copy definitions into the map.

If the project needs different fields (a team restructuring its architecture may want _Ports_ and _Today → target_), change them, keep them fixed across the page, and change `FIELDS` in the check to match.

## Flow

Track progress with these steps, in order.

### 1. Detect an existing map

Look before creating anything (skip `node_modules`, `vendor` and other dependency folders):

- files: `docs/capability-map.md`, `*capabilit*`, `CONTEXT.md`, `CONTEXT-MAP.md`, `docs/domain*`, `UBIQUITOUS_LANGUAGE.md`, `docs/glossary*`;
- a glossary or domain section in `AGENTS.md`, `CLAUDE.md`, `README.md` or `PRODUCT.md`;
- per-module domain docs (`*/knowledge/spec.md`, `*/README.md` describing a bounded context).

**What counts as a map:** a markdown file whose entries carry the map's fields (`**One line:**`, `**Is not:**` or similar). A checker script, an ADR or an agent-instructions section that mentions a map with no such file means the map was intended or lost: continue, carry what they say into the draft, and don't install a second checker in step 9.

**A capability map already there:** don't replace it. Tell the user where it is and stop, unless they asked to update it. Then follow [Updating a map](#updating-a-map).

**A glossary or domain doc, but no map:** that is the start of the map's language. Continue, and read it in step 3.

### 2. Ask for the client's sources

The code says what was built and what developers called it. The client's words live elsewhere. Ask the user, with the structured question tool (`AskUserQuestion` in Claude Code) or in chat, for:

- **the client's documents:** product descriptions, proposals, specs, the client's own manuals or site;
- **meeting notes and transcripts** from discovery or planning;
- **the people to ask** when a word is in dispute.

Accept what the user has. A draft from code and a glossary alone is still useful, but say in the report that its language is the developers', not yet the client's.

Don't send these documents anywhere outside the session. They are the client's.

### 3. Read the language first

Before reading code, read the sources from step 2, the glossary, `PRODUCT.md` or equivalent, and the ADRs. Write down:

- every domain noun and verb the client uses, with the source;
- the states a thing moves through, in the client's words;
- the roles and who does what;
- where the documents use two words for one thing, or one word for two things.

This list is the first draft of every _Language_ line, and of _Where the words still disagree_.

### 4. Propose the contexts and capabilities

From the language and a first look at the code (routes, top-level modules, models, permission lists), propose:

- the **contexts**, three to six;
- the **capabilities** in each, with an id and a one-line description.

Show the list to the user and let them correct it before mapping. If nobody can answer (a run without a user), decide, and put each cut you are unsure of in the questions. A wrong cut here costs every later step. A capability is a part of the business someone could own, not a folder: "membership" and "access-control" can live in the same module and still be two capabilities.

### 5. Map each capability

When the agent can run subagents, give each one a context, and the brief in [references/subagent-brief.md](references/subagent-brief.md) with the language list and the capability list filled in. Each returns one draft entry per capability, with citations.

For every entry:

- **Language** uses the client's word. If the code uses another, the client's word goes in the entry, and the pair goes under _Where the words still disagree_. If the project glossary already settled a word and a client document uses another, keep the glossary's word, which the team agreed, and ask the client.
- **Owns** names the tables or stores, and the rules on them: what must always hold, who can change what, the states and their transitions.
- **Who acts** checks the server. A permission checked only in the UI protects nothing; say so. A permission declared and seeded but checked nowhere goes under _Declared, not built_.
- **Is not** names the neighbouring capabilities by id. Write it from what the code does, then mark every _Is not_ you are unsure of for the questions list.
- **Decisions** cites ADRs that are in effect. A superseded ADR doesn't go in.
- **State** says what is missing, as found. Don't fix it.

**Check what comes back.** Subagents return confident claims, and some are wrong. Before writing the map, open the cited code yourself for:

- every claim that a check is missing: a permission checked only in the UI, a key checked nowhere, a rule the server doesn't enforce;
- every gap in _State_;
- one _Owns_ rule per capability, picked at random.

Check every path in _Lives in_ and every ADR ID in _Decisions_ with a script: they are cheap to check and embarrassing to get wrong.

### 6. Write the map

Copy [assets/capability-map.md](assets/capability-map.md) to `docs/capability-map.md` (or `doc/` if the repo has `doc/` and no `docs/`) and fill it in. Keep each field on one line: the check reads them line by line. Subagents tend to return bulleted fields anyway; fold them back into one line.

Keep each line short enough to review in a diff, about 300 characters. In _Lives in_, name folders, and files only where a capability shares a folder. In _Contracts_, group routes by prefix.

Write the closing sections from what the mapping found. They are often the most useful part of the page. They show the team where the domain and the code have drifted apart.

If the project has a glossary, every glossary term must appear in some _Language_ line or under _Declared, not built_. A term that names an app or a surface ("Operator portal", "Admin Portal") goes in the _Language_ line of the capability that owns sign-in to it. Any other term no capability speaks is a sign the glossary or the map is wrong. Put it in the questions.

### 7. Write the questions

End the report with the questions the draft leaves open. They belong in the description of the pull request that brings the map, so reviewers answer them there:

- every word in dispute: the code's word, the documents' word, where each appears;
- every _Is not_ line marked as unsure;
- every glossary entry the code contradicts (a role that doesn't exist, a concept that works differently);
- every capability whose boundary you guessed.

Group them by who should answer: the team, or the client.

### 8. Add the agent-instructions section

Pick the target file:

| Repo has                              | Edit                              |
| ------------------------------------- | --------------------------------- |
| `CLAUDE.md` that imports `@AGENTS.md` | `AGENTS.md`                       |
| only `AGENTS.md`                      | `AGENTS.md`                       |
| only `CLAUDE.md`                      | `CLAUDE.md`                       |
| both, no import between them          | ask the user which one (or both)  |
| neither                               | ask the user which file to create |

Use the file at the repository root. Add [assets/agent-instructions.md](assets/agent-instructions.md), replacing the placeholders. If the file ends in blocks a tool generates, insert the section before them.

The section holds a table of every capability with its context and one line, between two markers. Every agent session then knows what exists without loading the whole map. Fill the table by hand now, or let the check generate it in step 9.

### 9. Offer the check

If the repository already has a checker for the map (step 1), don't add this one. Report the existing one and stop this step.

Otherwise, ask with the question tool whether to add the check. Without a user to ask, add it and say so. Offer:

- **Add the check (Recommended).** Name where it would go and run in this project, such as "`scripts/capability-map.sh`, run as a step in your `lint` job".
- **Skip it.**

Say in one line what it does: it fails CI when the capability table is stale, an entry is missing a field or has them out of order, a heading isn't a capability id, or (with a glossary) a glossary term is spoken by no capability.

If the user wants it:

1. Copy [assets/capability-map.sh](assets/capability-map.sh) to `scripts/capability-map.sh` (or the repo's `script/` or `bin/`), and `chmod +x` it.
2. Set `MAP` and `AGENT_FILE`. If the project has a glossary in the `- **Term** — definition` format, set `GLOSSARY_FILE` and `GLOSSARY_HEADING`. If its glossary has another format, leave `GLOSSARY_FILE` empty and say so in the report. If you changed the fields, change `FIELDS`.
3. In a Node project, add `"capability-map:check": "bash scripts/capability-map.sh"` and `"capability-map:fix": "bash scripts/capability-map.sh --fix"` to `package.json`, without overwriting existing keys.
4. Run it with `--fix`, then without. It must pass on what this skill wrote. A glossary term it flags goes to the questions, not into a made-up _Language_ line.
5. Wire it into the project's CI. Find the CI system (`.github/workflows/`, `.gitlab-ci.yml`, `bitbucket-pipelines.yml`, `.circleci/config.yml` and so on). Read the pipeline and add one step that runs `bash scripts/capability-map.sh` where its lint-type checks run, in its own style. Watch for `paths:` filters that skip docs-only changes: the map is a doc, so the check must run on them. Show the user the exact change and confirm it before writing. The check needs only bash and awk, so it needs no setup step.

### 10. Report

- every file created or changed;
- the contexts and capabilities, one line each;
- what the mapping found: _Declared, not built_, words in dispute, seams, and gaps in _State_;
- the questions from step 7, grouped by who should answer;
- the sources the language came from, and whether the client's documents were among them;
- if the check was installed, how to run it and where it runs in CI.

Do not commit.

## Updating a map

- **A change that adds a capability, moves code between capabilities, or changes what one owns** updates the entry in the same pull request. Check the _Is not_ line first.
- **A new word goes into the glossary first**, then into a _Language_ line.
- **A superseded ADR comes off** the _Decisions_ line, replaced by the one that superseded it if it still binds.
- **Something declared becomes built:** move it from _Declared, not built_ into an entry.
- **Don't rename a capability id** casually. Agents and docs link to it. If a rename is right, update every link to it in the same pull request.
- Run the check with `--fix` after changing a _One line_.

## Gotchas

- **The code's words are not the client's words.** A model named `Asset` in a business that rents "pods" is a disagreement to record, not the word to use. Customer-facing copy that uses the code's word is worth a question.
- **A folder is not a capability.** One module can hold two capabilities, and one capability can span three apps. Map the business, then say where its code lives.
- **Permission lists lie.** A permission that is declared, seeded on a role and shown in the UI may be checked nowhere on the server. Mapping one real project found most of its declared permission keys unchecked. Check the server for every _Who acts_ claim.
- **Glossaries drift too.** Mapping can show glossary entries for roles that don't exist, or a concept that works differently in the code. Don't fix the glossary silently; put each case in the questions.
- **Overloaded words are the costly ones.** One word for two things ("admin" as a panel and as a separate app, "transaction" as a sale and a database transaction) misleads more than two words for one thing. List every one under _Where the words still disagree_.
- **Keep each field on one line.** The check reads fields line by line, and a field that wraps to a second line loses its continuation.
- **Don't put client confidential data in the map.** It is about the domain, not the data: no customer names, credentials, internal hostnames or partner names that the client hasn't cleared. "An external manufacturer" says enough.
- **The glossary check proves a term appears, not that it's used right.** It matches substrings, ignoring case, so a short term like "Pod" or "Role" passes almost anywhere. Read the _Language_ lines yourself.
- **`capability-map.sh` must stay portable:** bash 3.2 (macOS), POSIX awk (BSD awk on macOS, mawk on Ubuntu), no gawk or GNU-only flags. After changing it, run `node --test capability-map/tests/capability-map.test.mjs`, once with `CAPABILITY_MAP_TEST_BASH=/bin/bash` on macOS and once on Linux. Node is only the test runner.
- **CI checks the shape, not the truth.** An entry can go stale while CI stays green. Reviewers keep it true, which is why the agent-instructions section asks every boundary-moving change to update its entry.

## Further reading

- [Bounded Context](https://martinfowler.com/bliki/BoundedContext.html), Martin Fowler
- [Ubiquitous Language](https://martinfowler.com/bliki/UbiquitousLanguage.html), Martin Fowler
- _Domain-Driven Design_, Eric Evans
