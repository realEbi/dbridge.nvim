## Why

The explorer assumes two container tiers, duplicating SQLite namespaces, and completion has no selected scope. The companion server is adopting explicit Scope Paths, so the client must migrate in lockstep to preserve browsing and executable completion.

## What Changes

- Render the server-declared container levels, retaining each node's literal Scope Path and internal marker.
- Capture Session levels, default path, and SQL dialect; send explicit paths for metadata and completion and reread the declaration after refresh.
- Keep the selected scope with each query buffer/Session target; pass the reported dialect to statement selection.
- **BREAKING** Require the linked server contract; remove fixed database/schema fields, legacy fqn, and missing-identifier fallback.
- Preserve qualified table insertion text supplied by the server and verify execution across attached scopes.

## Capabilities

### New Capabilities

- `scope-browsing`: Declared hierarchy rendering and client-owned scope selection.

### Modified Capabilities

- `generated-table-queries`: Replace legacy addressing and older-server fallback with explicit Scope Paths and required identifiers.
- `sql-completion`: Send the query target's Scope Path and preserve executable table insertion text.

## Impact

Owner: dbridge.nvim, covering explorer, editor, completion, integration tests and owning docs. The server owns DSP and database behavior in the linked [server change](../../../../../dbridge/openspec/changes/archive/2026-09-24-adopt-explicit-scope-paths/). Both changes require one another; there is no old-server compatibility mode. Shared verification covers attached DuckDB catalogs and one-tier SQLite namespaces. This advances roadmap outcome 1 and server-hosted backlog [003](../../../../../dbridge/docs/backlog/003-database-hierarchy.md); Profile rename remains separate. The user explicitly authorized creating and implementing this linked change in the current session; commits and publishing remain unauthorized.
