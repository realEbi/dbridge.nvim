# 002 - Define Session lifetime across UI-only teardown and rebuild

- Repo: dbridge.nvim
- Status: deferred
- Change: none
- Origin: Session workflow source review during preserve-and-display-active-session.

## Problem / opportunity

Closing a panel tears down the UI without stopping the server. Opening the UI
again creates a new explorer tree, while its module-local Session map survives.
NuiTree derives default node IDs from Profile display text, so a recreated node
can reuse a binding without restored metadata; renaming or removing nodes can
also leave live server Sessions without a visible owner. Known server-stop
invalidation is covered by the Session workflow change, but UI-only teardown does
not stop that process.

Evidence: `init.lua` teardown unmounts panels and its next open calls
`explorer.init`; `explorer.lua` creates a fresh tree while `_sessions` is module
state. `DbridgeClose` explicitly stops the child, whereas panel teardown does not.

## Desired outcome

Define and verify whether UI rebuild restores tracked Sessions and metadata or
releases those Sessions. Preserve Profile/Session separation and avoid stale
bindings, invisible live Sessions, or unexpected loss of in-memory state.

## Notes and references

Use real-server checks for panel close/reopen, Profile rename, multiple Sessions,
and in-memory data. Coordinate with server-hosted Profile rename record 001.
This finding does not authorize a lifecycle redesign in the refresh change.
