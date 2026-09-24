## Context

See [proposal.md](proposal.md) for motivation and repository ownership. The client
already assigns monotonically increasing request IDs and removes callbacks when
replies arrive, but `request()` returns no ID. All editor and generated-table
execution enters `run_sql` in `init.lua`; completion sends independent requests.
No pending execution state or cancel control exists. Server interruption semantics
belong to the linked `adopt-async-orchestration` change, including best-effort normal
cancellation and bounded shutdown cleanup.

## Goals / Non-Goals

**Goals:** retain the existing callback transport, identify the latest outstanding
UI execution across active-Session changes, and keep cancellation feedback truthful.

**Non-Goals:** introduce a query-history UI, change result ordering, automatically
cancel completion, or infer/implement driver behavior in Lua.

## Decisions

1. `client.request()` returns the ID it already assigns, or nil if the server is
   stopped. Add `client.notify()` using the same framed sender and object-shaped
   empty params. `client.cancel(id)` sends the server-owned cancellation
   notification only while that ID has a pending callback; it returns whether it
   sent it. Keep the callback until the actual reply. Manufacturing a local
   cancelled reply would conceal successful effects or a server that ignores cancel.
2. `init.lua` tracks IDs submitted through `run_sql`, removing them before scheduling
   response presentation. `:DbridgeCancel` selects the largest outstanding ID.
   A set, rather than one latest pointer, lets an earlier slow query remain
   cancellable after a newer fast query replies. The captured ID makes Session
   selection changes irrelevant. The command reports "cancellation requested";
   only the cancellation error produces "query cancelled" at INFO level.
3. Clear transport callbacks and retire UI execution tracking on known process stop.
   UI cleanup prunes only IDs no longer pending, so a delayed stop event cannot
   clear a query submitted immediately after restart.
   Guard exit callbacks by process identity so a previous process's exit cannot
   clear a restarted process's requests. UI-only panel teardown does not cancel
   server work; preserve the existing lifecycle ownership and deferred item 002.
4. Use deterministic client tests for latest-query targeting, pending removal,
   feedback levels, and process cleanup, then real-server child-Neovim tests for
   SQLite/DuckDB cancellation, Session reuse, and DuckDB completion overtaking a
   long query. Explicitly select the server being implemented; no runtime dependency
   is added. Blocking waits stay inside child Neovim.

## Risks / Trade-offs

- [Older server ignores cancellation] → Keep waiting for its normal result and
  describe the control as requiring a supporting server; no false success feedback.
- [Completion or other fast replies interleave with execution] → Only execution IDs
  enter UI cancellation tracking; preserve existing callback correlation.
- [Long query test hangs] → Use bounded child waits, cancel in test cleanup, and stop
  each child/server through the existing harness.
- [UI closes while query remains pending] → Cancellation state belongs to the client
  process, not one panel. UI-only rebuild lifetime remains deferred in backlog 002.

## Migration Plan

The client and server changes are linked and verified together. The client can be
installed first: the previous server ignores cancellation notifications and normal
callbacks still work. Server rollback similarly restores that limitation. No
configuration or persisted Profile migration is needed. Record the exact selected
server revision/worktree in the session handoff and verification result.
