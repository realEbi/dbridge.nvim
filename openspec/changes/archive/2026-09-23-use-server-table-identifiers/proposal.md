## Why

Entering a table currently executes its bare name, which can select the wrong schema or fail for quoted names. This client half of [server backlog 002](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/002-qualified-identifiers.md) implements the daily targeting roadmap outcome using server-owned identifiers.

## What Changes

- Retain literal table identity and sql_identifier on explorer table nodes.
- Wait for metadata before generating the first sample SELECT.
- Preserve old-server compatibility only for successful responses lacking the identifier field; show metadata errors without executing guessed SQL.
- Verify the actual Enter mapping with real SQLite/DuckDB server Sessions.

## Capabilities

### New Capabilities
- `generated-table-queries`: exact table activation using server identifiers.

### Modified Capabilities
None.

## Impact

Neovim owns explorer state, asynchronous activation and presentation. Server owns the additive DSP contract in [qualify-generated-table-identifiers](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-23-qualify-generated-table-identifiers). No client dialect inference or new Session dialect RPC is introduced. Session refresh, indicators and statement selection are separate work.
