## Context

See [proposal.md](proposal.md). The existing tree hardcodes database/schema tiers and sends both legacy fqn and fixed table fields. Completion sends only Session ID. Statement selection infers syntax from adapter name. The linked server change owns the new DSP details; this design owns their client consumption.

## Goals / Non-Goals

Goals: retain truthful targeting and atomic refresh while removing hierarchy assumptions. Preserve asynchronous callbacks, late-response guards, and UTF-8 handling. Non-goals: new adapters, SQL parsing rules, server-held scope, saved-query management, or automatic DDL refresh.

## Decisions

- Build container nodes recursively according to declared levels; each node carries a literal path and internal flag. Listing table entries supply names and identifiers. This avoids per-adapter UI branches.
- Capture levels/default path/dialect from connect; build refresh replacements using the new declaration and commit it only with the successful tree swap. Preserve selected paths that remain listed; reset removed ones to the refreshed default. During replacement, restore the focused table or scope and expand its ancestors before publishing target updates; if the scope vanished, focus the Profile. This prevents a clamped cursor row from silently selecting another scope when CursorMoved runs.
- Keep an active path on each Profile's live Session binding. Selecting a partial container path fills its remaining components from the declared default. Record the resulting Session/path in the query editor buffer; other SQL buffers retain per-Session paths once acquired. The server never receives a scope mutation operation.
- Metadata and completion use paths only. Missing SQL identifiers fail visibly; no older-server fallback remains. The query editor receives reported dialect for its existing lexical scanner.
- Preserve server table insertion text, whose qualification is server-owned; no SQL quoting or qualifier construction moves into Lua.

## Risks / Trade-offs

- Breaking protocol → deploy client and server together and test against the sibling checkout.
- Attach/detach leaves stale metadata → explicit refresh rereads declaration and validates surviving paths.
- Async refresh or activation arrives late → retain existing tree/Session/generation identity guards.
- Partial-container selection may name a default suffix absent from that container → the server rejects invalid metadata/completion; users can select a displayed complete scope. No undeclared scope is guessed from SQL.

## Migration Plan

Create and review this linked change, implement against the companion server, run targeted and full real-server client checks, and synchronize/archive only after verification. Rollback requires restoring both repositories together. No commit, push, or release is authorized by this implementation request.
