---
name: threat-model
description: Write a threat model for a repository, kept in the repo next to the code. Maps what the system protects (assets), who from (actors), where trusted and untrusted data meet (trust boundaries) and every known threat, each with a stable ID, severity, status, STRIDE class and code citations. Also lists the controls already in place and what is out of scope, and adds a section to AGENTS.md or CLAUDE.md so changes that cross a boundary cite the threats they touch. Threats inferred from reading code are marked To verify; nothing is fixed, accepted or committed. Use when asked to write, draft, bootstrap or update a threat model, map trust boundaries or the attack surface, do a STRIDE pass over a codebase, or add a threat model to agent instructions.
license: MIT
metadata:
  author: geeksilva97
  version: "1.0"
---

# Threat model

Writes `docs/threat-model.md`: one document that says what the system protects, who it protects it from, where its trust boundaries run, and which threats are known. Then it wires the document into the agent instructions so it stays in use.

A threat model is not an audit. An audit goes stale on the next pull request and nobody can cite it. This one lives in the repository, gives every threat an ID that never changes, and is updated by the pull requests that change the system.

An agent doesn't know where a system's trust boundaries are. It treats a database row as truth even when a system the team doesn't control wrote it, and it "simplifies" a check without knowing which threat the check exists for. The model gives people and agents the same map.

## What this skill does not do

- **It fixes nothing.** Each fix ships in its own pull request, later, reviewed like any change.
- **It accepts nothing.** Living with a threat is a business decision. Only people make it, in an ADR.
- **It doesn't attack anything.** It reads code and configuration. It never sends requests to a deployed environment, production or otherwise.
- **It doesn't commit.**

## Conventions the model follows

- **Stable IDs.** Assets `A1…`, actors `X1…`, boundaries `B1…`, threats `T1…`. An ID is never reused or renumbered. A fixed threat stays in the document with its status changed.
- **Statuses:**
  - **Open:** real today, no decision taken.
  - **To verify:** inferred from reading the code. Needs a check against a running environment.
  - **Mitigated:** fixed. The entry says by what.
  - **Accepted:** the team lives with it. The entry cites the ADR that says why.
- **Where the fix lives:** **Here** (this repository can fix it alone) or **Outside** (another system, or hosting and cloud configuration this repository can't see, owns the fix; this repository can only contain it). Pick the project's own name for "here", such as "Portal" or "API", and use it everywhere the template says `<Here>`. A threat can be both: "Outside, contained by the Portal".
- **Every threat cites evidence**: the files and functions involved. A threat with no citation is a guess and doesn't go in.
- **Every control says where it stops.** "The Host allowlist defends against DNS rebinding. It doesn't stop a client that can reach the port, because that client sets Host freely." This honesty is what makes the model useful.

## Flow

Track progress with these steps, in order. Steps 3 and 4 feed each other: the mapping raises premise questions, and the premise decides what matters in the mapping. Agree what you can first, map, then bring the new questions back to the user before step 6.

### 1. Detect an existing model

Look before creating anything (skip `node_modules`, `vendor` and other dependency folders):

- files: `docs/threat-model.md`, `THREAT_MODEL.md`, `threat-model.md`, `docs/security/*`, anything named `*threat*`;
- a `## Threat model` (or similar) section in `SECURITY.md` or `docs/security.md`;
- mentions of "threat model" in `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, ADRs and docs.

**If a model exists in another format, don't replace it.** Tell the user where it is and stop, unless they asked to update it. Then follow [Updating a model](#updating-a-model) in the format it already has.

**If it is this skill's format**, go to [Updating a model](#updating-a-model).

A mention with no document means the model was intended but never written. Continue, and carry what the mention says into step 2.

### 2. Check where the document will be read

A threat model is also a map for an attacker. Check whether the repository is public: `gh repo view --json visibility`, or the remote's host and the user's answer.

**If it is public**, stop and ask before writing open threats into it. Offer:

- write only the premise, assets, boundaries, controls and out-of-scope sections in the repository, and keep open threats in a private place the user names;
- write it all locally without committing, for the user to decide;
- write it all in the repository (only if the user says the threats are already public or fixed).

For a private repository, continue.

### 3. Agree the premise with the user

The premise comes from people, not from the code. Everything else in the model follows from it. Read the README, `AGENTS.md` or `CLAUDE.md`, product docs and ADRs first, so you can propose an answer instead of asking an empty question. Then ask, with the structured question tool (`AskUserQuestion` in Claude Code) or in chat:

- **Scope.** Which apps and services in this repository are in scope?
- **Neighbours.** Which systems outside this repository read or write the same data, or receive commands from it? Which of them does the team control?
- **Exposure.** Is it on the open Internet, an internal network, a single machine?
- **Tenancy.** One customer per deployment, or several sharing one?
- **What hurts most.** What would the client least want to lose: money, physical control of devices, personal data, one tenant seeing another, uptime?

Propose your reading of each from what you read, and let the user correct it. Don't continue on an unconfirmed premise. If the user can't answer something, write it in the premise as an open question.

**A neighbour that writes this system's data is untrusted**, even when it is "ours". Say so in the premise: _"treat its rows as input, not truth"_.

### 4. Map the system

Read the code to find every place where data crosses from one trust level to another. When the agent can run subagents, split the mapping by area and run them in parallel. Each one returns findings with file and function citations.

[references/mapping-checklist.md](references/mapping-checklist.md) lists what to look for in each area:

- **entry points:** routes, webhooks, sockets, jobs, scheduled tasks, CLIs, admin panels;
- **authentication and sessions:** guards, tokens, cookies, password reset, invitations;
- **authorization:** where permissions are checked, and every early return that skips the check;
- **data stores:** what each holds, and who else writes it;
- **outbound integrations:** payment, devices, email, storage, third-party APIs, and how each one authenticates;
- **files and media:** uploads, signed links, who can read what;
- **secrets and configuration:** where they come from, and who else can read them;
- **build and deploy:** CI, package registries, action pinning, deploy targets.

Give every subagent the same brief: [references/subagent-brief.md](references/subagent-brief.md), with the premise and its area filled in. It fixes the shape of what comes back. Without it, each subagent numbers its own threats and proposes its own severities, and reconciling six such reports costs more than the mapping.

**Check what comes back before using it.** Subagents return confident citations, and some are wrong. Before step 6, open the cited code yourself for every candidate that could be High, and for every candidate you plan to merge into a chain.

### 5. Name the assets, actors and boundaries

From the premise and the mapping:

- **Assets (`A1…`)**, ordered by the harm their loss does. Say in one line why each one matters.
- **Actors (`X1…`)**: anonymous Internet, each kind of signed-in user, another tenant, each kind of staff, a compromised staff account, each neighbouring system, a network peer, the supply chain. Keep the ones that apply.
- **Boundaries (`B1…`)**: one per crossing. For each, say what crosses it and what checks it. Draw an ASCII diagram when there are more than three. Keep it to one screen: group crossings that share a channel and a check (all browser traffic, all calls to one cloud provider) into one boundary.

### 6. Find the threats

Walk each boundary with STRIDE (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege). For each actor that can reach the boundary, ask what it could do to each asset behind it.

For every threat you keep:

- cite the evidence: files, functions, configuration;
- name the boundary, the STRIDE class and the assets;
- propose a severity with the rubric below. Say it's a proposal;
- set the status (see below);
- say where the fix lives;
- end with **Mitigation options**, and add a **Verify** line for whatever part the code doesn't show.

**Status.**

- **Open** when the code shows the harm, even if part of it depends on something outside. Put the outside part in a **Verify** line.
- **To verify** when the harm depends entirely on configuration, deployment or behaviour the code doesn't show.
- **Mitigated** only with the evidence of the fix.
- **Never decide Accepted yourself.** If an existing ADR already accepts the risk, check its assumptions. When they still hold, the threat is **Accepted** and cites that ADR. When one broke (a control it relied on was never built, a later ADR contradicts it), the threat is **Open**, and the entry says which assumption broke.

**Severity.** Rate the harm, then how easy it is to reach:

| Harm to the asset                                                                         | Reached by anyone, or any signed-in user | Needs a specific role, a neighbour or a network position | Needs a compromised account or several unlikely steps |
| ----------------------------------------------------------------------------------------- | ---------------------------------------- | -------------------------------------------------------- | ----------------------------------------------------- |
| Physical harm, money moved, sensitive personal data, one tenant reaching another, takeover | High                                     | High                                                     | Medium                                                |
| Data of one tenant, an account, the audit trail, availability of a core flow             | Medium                                   | Medium                                                   | Low                                                   |
| Hygiene: missing hardening, noise, cost                                                   | Low                                      | Low                                                      | Low                                                   |

Rank a **To verify** threat by the worst case its Verify line would confirm, and say so in the entry ("High if the port is reachable").

**Merge by chain.** Merge findings when **the same actor** completes the harm through them. "Staff can sign in to the customer app" and "staff bypass permission checks" are one threat: together they are the harm, and splitting them hides the chain. When a **different actor** feeds the chain (a seeded account that becomes staff, an attacker who squats a staff email), keep it separate and cross-reference the IDs.

**Aim for a model people read.** A first model of a real product usually holds 10 to 20 threats. If you have many more, you are listing findings, not threats: merge findings that share a root cause or a fix, and fold small hygiene items into one Low entry per area ("Account security baseline", "Build hardening"). Every finding stays in the evidence bullets of the threat it belongs to.

**Number them.** Order by severity. Within a severity, put the higher-ranked asset first, then Open before To verify. Then number. Numbers are permanent from now on.

### 7. List the controls in place

Record the defences that already work, with citations, grouped by area (sessions, credentials, tenant isolation, input validation, files, headers…). For each, say where it stops.

This section is what stops a later change from weakening a defence without anyone noticing. Don't skip it because it has no findings.

### 8. Write the document

Copy [assets/threat-model.md](assets/threat-model.md) to `docs/threat-model.md` (or `doc/` if the repo has `doc/` and no `docs/`) and fill it in. Keep the section order. Link the project's glossary, capability map and ADR index from the intro when they exist.

Cite decisions by the ID the project's ADRs use. Cite code by path, relative to the app root, and say which root in the intro. In a repository with several apps, cite from the repository root.

### 9. Add the agent-instructions section

Pick the target file:

| Repo has                            | Edit                                       |
| ----------------------------------- | ------------------------------------------ |
| `CLAUDE.md` that imports `@AGENTS.md` | `AGENTS.md`                                |
| only `AGENTS.md`                    | `AGENTS.md`                                |
| only `CLAUDE.md`                    | `CLAUDE.md`                                |
| both, no import between them        | ask the user which one (or both)           |
| neither                             | ask the user which file to create          |

Use the file at the repository root. Nested `apps/*/CLAUDE.md` or `AGENTS.md` files are for app-level rules.

Add [assets/agent-instructions.md](assets/agent-instructions.md) at the end of the file, replacing the placeholders. If the file ends in blocks a tool generates (marked by comments such as `<!-- BEGIN … -->`), insert the section before them. If the premise names neighbours that write this system's data, keep the sentence about them and name them. Otherwise remove it.

**Run the repository's own checks on both files.** Formatters (`prettier --check`), markdown linters, and doc checks such as an ADR checker that validates citations and links. The model cites many ADRs and paths, so expect a failure or two. Fix what fails in the files you wrote.

### 10. Offer an ADR

If the repository keeps ADRs, offer to write one that records the decision to keep a threat model in the repository, with stable IDs, acceptance through ADRs, and the same-PR rule. Follow the repository's own ADR format and naming. Status **Proposed**: the team accepts it in review.

If the repository has no ADRs, mention that accepting a threat needs one, and that the `adr-setup` skill sets them up.

### 11. Report

- every file created or changed;
- the count of threats by severity and status;
- each **High** threat in one line;
- every **To verify** threat, with what to check;
- the open questions from the premise;
- what the user should do next: read every threat against the cited code, agree the severities with the team, and open one task per fix.

Do not commit.

## Updating a model

When the model already exists:

- **Keep every ID.** Add new entries with the next free number. Never renumber, even if severities changed.
- **A threat that is fixed** turns **Mitigated**, and the entry says by what (commit, PR, file). Keep the entry.
- **A To verify threat** turns **Open** or **Mitigated** only with the evidence for it.
- **A new route, integration, shared table or neighbour** adds or extends a boundary.
- **When a dependency is retired**, revisit every threat whose fix lives outside.
- **Never change a status to Accepted.** Point the user to an ADR instead.

Report what changed, by ID.

## Gotchas

- **Don't write secrets into the model.** Cite the environment variable or the file that holds a secret, never its value. The same goes for internal hostnames and customer data seen in fixtures or seeds. When the threat *is* a credential in the repository (a seeded account, a committed key), cite the file and the function that holds it, and leave out the login and the secret. Leave out the names of the client's partners, suppliers and customers too: "an external manufacturer" says enough.
- **Frontend checks are not controls.** A button hidden from a role protects nothing if the route behind it doesn't check the permission. Check the server for every permission the UI enforces. On one project, most declared permissions were never checked by the server.
- **Look for early returns in authorization.** An `if (user.isAdmin) return next()` before the permission check makes every admin hold every permission, in every tenant. Then check which roles count as "admin".
- **Shared databases make neighbours into writers.** If another system writes a table this one reads, every field in it is input. That includes flags such as `is_admin`, statuses, and amounts.
- **Two records can each be right and together be wrong.** An early ADR that assumes all staff are trusted and a later one that adds narrow staff roles conflict. Read the ADRs about auth and roles together.
- **"Internal network" is not a control.** Say what stops a peer on that network, or say that nothing does.
- **Don't verify against production.** A To verify threat says what to check. A person checks it, in an environment they are allowed to test.
- **The model is only as true as the last pull request that touched it.** Nothing checks the content mechanically. Reviewers do, which is why the agent-instructions section asks every boundary-crossing change to cite IDs.

## Further reading

- [Threat Modeling Manifesto](https://www.threatmodelingmanifesto.org/)
- [OWASP Threat Modeling Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Threat_Modeling_Cheat_Sheet.html)
- [STRIDE threat classes](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [ai-memory threat model](https://github.com/akitaonrails/ai-memory/blob/main/SECURITY.md#threat-model), a short example: premise, in scope with where each control stops, out of scope
