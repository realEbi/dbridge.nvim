## Context

The editor currently returns the entire buffer or a visual selection. The server
executes submitted SQL with its Adapter; it does not select statements. See the
proposal for backlog ownership. The existing client remains asynchronous, and
server execution remains synchronous.

## Goals / Non-Goals

Add an explicit statement action without changing established execution mappings.
No multi-result runner, server parser RPC, transaction API, or arbitrary stored
procedure grammar is introduced. The scanner covers the currently supported
SQLite and DuckDB lexical forms, including SQLite trigger bodies.

## Decisions

- Add a small pure Lua statement scanner, separate from the editor/UI, returning
  the selected SQL or a diagnostic. A plain semicolon split corrupts strings and
  trigger bodies. Requiring a Treesitter SQL parser would add an unavailable
  runtime dependency to a previously dependency-free selection action.
- Scan bytes so offsets match Neovim. Retain comments with their following
  statement and the terminator with its preceding statement. Skip executable
  selection for comment-only ranges; detect incomplete lexical constructs.
- Track SQLite CREATE [TEMP|TEMPORARY] TRIGGER BEGIN/CASE/END nesting, including
  EXPLAIN and EXPLAIN QUERY PLAN wrappers, so internal semicolons do not become
  separately executable statements. Inspection-only SQL must retain its wrapper
  instead of exposing a trigger-body mutation as a standalone query.
- Route the new mapping and command through the existing active-Session selector,
  asynchronous execution callback, error notifications, and results rendering.
  Preserve `<leader>r` and visual-selection behavior.
- Use the companion Session workflow's `get_active_target().adapter` for lexical
  differences: SQLite bracket identifiers/non-nested comments and DuckDB arrays/
  nested comments. Shared integration must verify this dependency. The selector
  is optional for older client modules; their generic lexical behavior remains
  available, but per-Adapter edge cases require the companion target metadata.

## Risks / Trade-offs

- SQL dialect syntax evolves → document lexical support, cover supported Adapter
  cases, and leave future procedural grammars to explicit follow-up work.
- A new selector could execute neighboring SQL → assert exact selections plus
  real SQLite/DuckDB side effects through the command and actual mapping.
- Incomplete input could hide later delimiters → fail clearly for the selected
  incomplete range while retaining earlier complete ranges.

## Migration Plan

Restart Neovim with the updated client. Existing mappings and DSP shapes remain
compatible; no database or Profile changes are needed.
