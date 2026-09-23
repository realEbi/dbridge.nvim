## Context

The explorer owns live Session bindings keyed by Profile node ID. Query execution and completion already share its active-Session selector. Schema browsing uses asynchronous client callbacks against the existing synchronous server. No client ADR exists; this change preserves those boundaries.

## Goals / Non-Goals

Preserve the live database state while replacing only its metadata view, and expose exactly the target selected by existing SQL operations. Do not change DSP, infer database credentials, redefine Profile rename, or add automatic server restart recovery.

## Decisions

- Build replacement metadata off-tree and swap it after every introspection request succeeds. Removing children before fetching would hide valid metadata on an error. Associate each load with the tree identity, Session binding, and refresh generation so stale replies cannot resurrect deleted nodes or overwrite a later refresh.
- Keep the current selector's priority: connected Profile under the explorer cursor, then last interacted Profile, then connected root. Return target metadata from that selector; derive the Session ID and editor display from it. A separate display selection could disagree with execution.
- Put Profile name, adapter, and full Session ID in the query editor winbar. This leaves results pagination intact and avoids exposing configuration or credentials. Escape statusline formatting and controls in Profile text. Refresh the display on state changes and window/cursor events; show no active Session when no live target is available. Known server-stop callbacks invalidate Session bindings and metadata without reconnecting.
- Capture the adapter used to create a Session separately from editable Profile configuration, so the indicator does not relabel an existing Session after Profile edits.

## Risks / Trade-offs

- Concurrent refreshes and deletion can complete out of order → guard responses by generation and tree membership.
- Metadata gathering requires all listings before display → retain previous tree until a complete replacement is available, and report the failing RPC.
- The winbar has finite width → Neovim truncation can hide long names; no secrets or database config are included.
- The server has no Session-lifecycle notifications → known stopped-server state produces no active target; broader restart recovery remains deferred.

## Migration Plan

No persisted-data or DSP migration. Updating the plugin enables the behavior; reverting the change restores the previous UI. Verify with real SQLite and DuckDB server Sessions and isolated Profiles before synchronizing the capability.

### Integration refinement: disposed panels

Pending schema and connect callbacks also check that the explorer panel buffer is still valid. A late connect reply for a disposed UI releases its newly created Session, and a late refresh leaves the disposed tree untouched. This guard does not resolve ownership of Sessions already established before UI-only teardown (client backlog 002).
