## Why

The linked server change [`extract-table-key-constraints`](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-24-extract-table-key-constraints)
replaces `getTableSchema`'s `primary_keys` list with `primary_key: {name, columns}`
and reshapes foreign keys into one entry per constraint. This client's real-server
transport test asserts the old `primary_keys` field and fails against that server.
It resolves [backlog 005](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/005-duckdb-constraints.md)
together with the server change and supports roadmap outcome 1.

## What Changes

- Update `tests/test_transport.lua` to assert `primary_key` for the SQLite `users`
  table and the absence of `primary_keys`.
- No production code changes: no client module reads `primary_keys` or
  `foreign_keys`. Showing keys in the explorer is out of scope.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. No client-visible behavior changes, so this change sets `skip_specs: true`.
The key contract belongs to the server's `table-keys` capability and is not
restated here.

## Impact

Affects one client test. The shared DSP change is breaking for the key fields only;
the server change merges first, and this change is verified against it with
`DBRIDGE_SERVER_CMD`. After both merge, the client test suite requires a server that
includes `extract-table-key-constraints`.
