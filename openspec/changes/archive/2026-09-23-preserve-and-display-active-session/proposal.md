## Why

Refreshing schema currently drops the client binding and creates a new Session, losing in-memory data while leaving the old Session alive. The editor also hides which Profile/Session will receive queries and completion requests.

This implements server-hosted backlog [028](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/028-active-session-indicator.md) and [029](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/029-client-schema-refresh.md), within client roadmap outcome 1. Backlog 029 says refresh disconnects first; source inspection shows no disconnect, so the actual defect includes a leaked Session.

## What Changes

- Refresh metadata on the same Session and keep existing metadata when refresh or introspection fails.
- Show the execution/completion target's Profile, adapter, and Session ID in the query editor, with an explicit no-active-Session state.
- Keep the display synchronized with selection, connection, deletion, refresh, and panel focus.
- Verify memory/temporary data preservation and multi-Profile targeting against the real server.

## Capabilities

### New Capabilities
- `session-workflow`: Preserve Sessions during metadata refresh and visibly identify the target used by SQL operations.

### Modified Capabilities
None.

## Impact

Only dbridge.nvim runtime, documentation, and tests change. The server owns database state and DSP; existing refreshSchema and introspection RPCs are sufficient, with no protocol change or new dependency. Server-hosted backlog resolution is coordinated by the integrating parent change. Profile rename, identifier generation, and server restart recovery remain separate work.
