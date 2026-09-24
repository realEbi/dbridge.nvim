## Why

The client can submit a long query but cannot ask the server to stop it. The linked
server [async orchestration change](https://github.com/realEbi/dbridge/tree/dbridge-2.0/openspec/changes/archive/2026-09-24-adopt-async-orchestration)
adds cancellation; this change supplies the editor control and truthful feedback
for [backlog 009](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/009-query-cancellation.md)
and [roadmap outcome 3](../../../../docs/roadmap.md#3-integrate-server-supported-long-running-and-large-result-workflows).

## What Changes

- Return each submitted request's id from `client.request` and provide a client
  notification helper plus cancellation of an outstanding request.
- Add `:DbridgeCancel` to request cancellation of the latest still-outstanding
  query submitted through the editor or table execution flow, regardless of later
  active-Session changes.
- Report confirmed cancellation informationally and keep the previous results.
  Sending a cancellation does not claim it succeeded; normal results still render
  if the server completes the query normally.
- Clear request/query tracking on replies and server stop, and verify completion
  and request correlation while a long DuckDB query runs.

## Capabilities

### New Capabilities

- `query-cancellation`: Editor cancellation targeting, feedback, lifecycle cleanup,
  and using completion while an execution is outstanding.

### Modified Capabilities

None. Existing statement selection, Session targeting, and completion insertion
contracts remain unchanged.

## Impact

This repository owns `client.lua`, query interaction in `init.lua`, client tests,
and user/current-state documentation. The server repository owns the DSP
cancellation, concurrency, interruption, and shutdown contracts through
`adopt-async-orchestration`; this change does not duplicate them.

The client already correlates replies by id. The control requires a supporting
server for actual cancellation; older servers ignore the notification, and a
normal eventual result remains valid. No dependency is added. Progress reporting,
streaming, pagination changes, and automatic cancellation of completion are out of
scope. Verify the paired changes with real SQLite/DuckDB Sessions and child Neovim.
