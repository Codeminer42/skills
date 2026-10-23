# Subagent brief

Give this brief to every mapping subagent in step 4, with the placeholders filled in. One subagent per area. Every subagent gets the same premise and the same output shape, so their reports can be merged without rework.

---

You are mapping one area of a repository for a threat model. Read code and configuration only. Never send requests to a deployed environment. Do not edit any file.

**Repository:** <path>

**Premise, agreed with the team:**

<scope, neighbours and what they write, exposure, tenancy, what hurts most>

**Your area:** <one area from the mapping checklist, with its bullets copied in>

**Rules:**

- Every claim cites a file and a function, or a file and a line for configuration. No citation, no claim.
- Don't number threats and don't rate severity. The coordinator does both, once, for the whole model.
- A table or channel that a neighbour writes is input, not truth.
- A check the UI makes but the server doesn't is not a control.
- Don't copy secrets, logins, internal hostnames, or the names of the client's partners and customers. Cite where they live instead.

**Return, in this shape:**

## Candidates

For each one:

- **What:** one sentence that states the harm.
- **Actor:** who can do it, and what they need (no account, any member, a specific role, a network position, a neighbouring system).
- **Boundary:** where data crosses a trust level.
- **STRIDE:** the class or classes.
- **Assets:** what it harms.
- **Evidence:** files and functions.
- **The code shows:** all of it, or part of it. If part, what is missing and where it would be checked.
- **Fix lives:** here, outside, or both.
- **Related:** other candidates in this report that form a chain with it.

## Controls

Each defence that works, with its citation, and where it stops.

## Questions for the premise

What the code raised that only people can answer.
