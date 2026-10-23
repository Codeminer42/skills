# Capability Map

> One entry per capability of <system>, same template throughout: the essence in one line, the language it speaks, what it owns, its contracts, who acts on it, what it is _not_, where its code lives, the decisions that bind it, and its state. Read it to answer "what lives here and why" before opening the code. A capability spans every app; the map follows the domain, not the folder. Words are defined in <the glossary>; decisions are cited by ID (<the ADR index>). Paths are relative to <roots> unless written in full.

# <Context>

What this context covers, in one sentence.

## <capability-id>

**One line:** what it is, in one sentence a client would recognize.
**Language:** the client's words for it, and the states a thing moves through.
**Owns:** the tables or stores it owns, and the rules that always hold on them.
**Contracts:** routes, events, emails and jobs others use.
**Who acts:** who may use it, and what checks it on the server.
**Is not:** what it doesn't do, and which capability does (by id).
**Lives in:** its code, across every app.
**Decisions:** ADR-ID what it decided · ADR-ID what it decided.
**State:** built, partial or planned, and the gaps found while mapping.

# Declared, not built

Permissions, flags and concepts that exist and nothing implements. When one is built, it gets an entry above.

- **<name>** — where it is declared, and what is missing.

# Where the words still disagree

- **<word>** in <where> means <one thing>; in <where> it means <another>. <Which one wins, or that it is open.>

# Seams worth knowing

Where one rule is split across capabilities: not wrong, but a change on one side needs the other.

- **<rule>** is enforced in <capability> and in <capability>.

---

> **How to keep this page true.** A pull request that moves a boundary (a new capability, code moving between capabilities, a change to what one owns) updates the entry in the same diff; the **Is not** line is the one to check. A new word goes into the glossary first, then into a **Language** line. A superseded decision comes off **Decisions**.
