# Agent notes

- Node 20+, ES modules, no dependencies. `npm test` runs `node --test`.
- Two sources describe a store's shelves:
  - the **layout** (`src/layout.js`): which product each bin should hold, named from the
    store's own catalog, which always has a name;
  - the **stock scan** from the handhelds: what is actually in each bin. Its `name` comes
    from the global product master and is `null` for store-only products (own brands,
    local suppliers). Never prefer a scan name over a layout name.
