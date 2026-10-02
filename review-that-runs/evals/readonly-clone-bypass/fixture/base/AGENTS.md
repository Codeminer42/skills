# Agent notes

- Node 20+, ES modules, no runtime dependencies. `npm test` runs `node --test`.
- `src/query.js` is the in-house query builder every model reads and writes through.
  `paginate()` clones the builder to count rows, so anything a model attaches to a
  builder must survive `clone()`.
- The audit log is evidence for the compliance team: nothing in this service may change
  or delete an audit entry once it is written.
