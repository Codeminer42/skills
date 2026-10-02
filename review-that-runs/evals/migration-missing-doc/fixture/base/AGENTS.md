# Agent notes

- Node 20+, ES modules, no dependencies. `npm test` runs `node --test`.
- Data migrations live in `migrations/NNN_name.js` and export `up(db)` and `down(db)`.
  **Every migration opens with a JSDoc block saying what data it changes and why**, and
  what `down()` can and cannot restore. The PR description is not a substitute: it is
  gone once the PR merges, the migration file is not. See `migrations/001_split_names.js`.
