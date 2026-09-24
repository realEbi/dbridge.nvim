## Why

The server's selected backlog 018/053 work adds scoped unqualified SELECT
suggestions and a bare-SELECT fallback. The current Client replaces a column's
suffix only after a dot, so accepting an unqualified suggestion midway through
`name` can produce `nameme` with nvim-cmp's default Insert behavior.

## What Changes

- Replace the whole current identifier for every returned column suggestion,
  preserving surrounding SQL and UTF-8 byte positions.
- Verify real nvim-cmp SELECT-comma, typed-prefix, midword, Unicode, and keyword
  fallback flows against SQLite and DuckDB through the companion server.
- Preserve qualified dot triggering and table/keyword insertion behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sql-completion`: Extend column acceptance to unqualified identifiers.

## Impact

The Client owns identifier replacement and menu interaction. The linked server
change [complete-unqualified-select-targets](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-23-complete-unqualified-select-targets)
owns suggestions and DSP semantics for server backlog
[018](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/018-select-comma-completion.md) /
[053](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/053-bare-select-offers-nothing.md), supporting the
roadmap's precisely selected SQL outcome. The wire contract does not change;
older servers remain compatible but do not gain the new SELECT suggestions.
This slice changes cmp.lua, its real integration tests, user/developer docs,
architecture, roadmap, and the existing completion capability. It does not alter
trigger policy, ranking, server inference, Profile state, or unrelated plans.
