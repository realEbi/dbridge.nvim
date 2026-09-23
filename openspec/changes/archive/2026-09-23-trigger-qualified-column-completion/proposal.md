## Why

Typing `p.` in `SELECT p.name, p.category FROM products p LIMIT 100` does not
automatically request column suggestions. The source has no dot trigger, and
accepting an item inside an existing identifier can duplicate its remaining text.

## What Changes

- Trigger the configured dbridge nvim-cmp source when the user types `.`.
- Replace the column identifier on acceptance, preserving its qualifier and
  surrounding SQL, including when the cursor is inside an existing identifier.
- Verify automatic triggering and acceptance against the updated real server.

## Capabilities

### New Capabilities

- `sql-completion`: Qualified-column triggering and insertion in the Neovim Client.

### Modified Capabilities

None; this repository has no existing capability specs.

## Impact

dbridge.nvim owns completion-source interaction and insertion; dbridge owns SQL
resolution in the companion
[`complete-alias-qualified-columns`](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-23-complete-alias-qualified-columns)
change. The existing DSP request and response shapes remain compatible. Alias
suggestions require that server fix as well as this client fix. nvim-cmp stays
optional at runtime and becomes a test dependency for exercising actual editing.

Related record: server backlog
[015](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/015-alias-completion.md),
under its richer SQL assistance milestone. No existing client roadmap outcome
specifically covers this defect. CTE/derived-column inference and broader SQL
semantics remain server work; lifecycle and user keymap changes are out of scope.
