# Subagent brief

Give this brief to every mapping subagent in step 5, with the placeholders filled in. One subagent per context. Every subagent gets the same language list and the same output shape, so their entries fit together.

---

You are mapping one context of a repository for a capability map. Read code, configuration and docs only. Do not edit any file.

**Repository:** <path>

**The client's language,** from their documents and the glossary:

<the list from step 3: words, states, roles, and where the documents disagree>

**All capabilities, by context,** agreed with the user:

<the list from step 4: id, context, one line>

**Your context:** <context>, with these capabilities: <ids>

**Rules:**

- Every claim cites a file, and a function where it matters. No citation, no claim.
- Use the client's word from the language list, not the code's. When the code uses another word, report the pair.
- Check the server for every permission. A check only in the UI is not a check. A permission declared or seeded and checked nowhere is "declared, not built".
- Name neighbouring capabilities by id in **Is not**. If the boundary is unclear, say so instead of guessing.
- Fix nothing. Report gaps as found.
- Keep every field on one line.
- Don't copy customer data, credentials, hostnames, or the names of the client's partners.

**Return, for each capability:**

```markdown
## <id>

**One line:** …
**Language:** …
**Owns:** …
**Contracts:** …
**Who acts:** …
**Is not:** …
**Lives in:** …
**Decisions:** …
**State:** …
```

Then three lists:

- **Words in dispute:** the code's word, the client's word, and where each appears.
- **Declared, not built:** what exists and nothing implements, with its citation.
- **Unsure:** every Is not line or boundary you are not sure of, and why.
