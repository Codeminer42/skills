# Agent notes

- Node 20+, ES modules, no dependencies. `npm test` runs `node --test`.
- `src/db.js` is a stand-in for the SQL client: same API, same errors. Like the real
  client, `insertMany([])` throws `EmptyInsert: the query is empty` instead of doing
  nothing, so callers must not pass an empty list.
