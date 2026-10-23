# Threat Model

> What <system> protects, who it protects it from, where the trust boundaries run, and which threats are open, accepted or mitigated. The model covers <apps and services in scope>, and every system they trust. <Neighbour> is not in scope as a target; it is in scope as a neighbour that <writes the same data / receives the same commands>.
>
> Every asset, actor, boundary and threat has a stable ID (`A1`, `X1`, `B1`, `T1`). Cite threats by ID in pull requests, reviews and ADRs. An ID is never reused: a threat that is fixed stays here with its status changed. <Words are defined in <glossary>; capabilities in <capability map>; decisions are cited by ID (<ADR index>).> Paths are relative to <root>.

**Status:** **Open** — real today, no decision taken. **Accepted** — an ADR records why we live with it. **To verify** — inferred from code, needs a check against a running environment. **Mitigated** — fixed; the entry says by what.

**Where the fix lives:** **<Here>** — this repository can fix it alone. **Outside** — the fix belongs to <the systems that own it>, or to hosting and cloud configuration this repository can't see; this repository can only contain it.

# The premise

What kind of system this is, who is trusted, and what it shares with systems it does not control.

So the model treats <neighbours> as **untrusted neighbours that write this system's data**, not as internal components.

Open questions: <what the team could not answer yet>.

# Assets

Ordered by the harm their loss does.

- **A1 — <asset>.** Why losing it hurts.

# Actors

- **X1 — Anonymous internet.** What it reaches.

# Trust boundaries

```
<small diagram of the boundaries>
```

- **B1 — <from> to <to>.** What crosses it and what checks it.

# Threats

Ordered by severity. Each entry names its boundary, STRIDE class and asset.

## T1 — <one sentence that states the harm>

**<High|Medium|Low> · <Open|To verify|Mitigated|Accepted> · <Here | Outside | Outside, contained by Here | Here and Outside>** · <B?> · <STRIDE class> · <A?, A?>

- Evidence, with the files and functions involved.
- **Mitigation options:** what would fix or contain it.
- **Verify:** what the code doesn't show, what to check, and where. (Omit when the code shows it all.)

For a fixed threat, replace the last two lines with **Mitigated by:** the change that fixed it. For an accepted one, with **Accepted in:** the ADR, and what would make the team revisit it.

# Out of scope

What this system does not defend against, and why.

# Controls in place

What the review found solid, so changes do not weaken it unknowingly. Each control says where it stops.

- **Sessions.** …

# Keeping it true

- A pull request that crosses a boundary (`B1`–`B?`) names the threats it touches, by ID, in its description. A reviewer who sees a boundary crossed with no ID asks for one.
- A fix changes its threat to **Mitigated** in the same pull request, and says by what. The entry stays.
- Living with a threat takes an ADR. The entry turns **Accepted** and cites it.
- A new external system, inbound route or shared table adds a boundary or extends one here, in the same pull request that brings it.
- When a dependency is retired, revisit every **Outside** entry.
