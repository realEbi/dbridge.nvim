# Verification

## EXPLAIN trigger integration regression

Read-only review reproduced valid SQLite `EXPLAIN CREATE TRIGGER ... BEGIN
INSERT ...; UPDATE ...; END;` being split so a cursor at UPDATE selected only
that mutation. SQLite executed the complete EXPLAIN without mutating data, while
the selected fragment would modify it.

The scanner now recognizes EXPLAIN and EXPLAIN QUERY PLAN wrappers before CREATE
[TEMP|TEMPORARY] TRIGGER. Exact-selection tests cover both forms. Real SQLite
command tests assert the full inspection request is sent, existing audit rows
remain unchanged, no temporary trigger is created, and neighboring SQL is not
executed. The integration statement suite passes all 45 cases; the standalone
lane uses an explicit integration-server command because it has no sibling
dbridge checkout. The standalone focused run also passed all 45 cases.

## Completed behavior and shared verification

- Pure selector cases verify strings and escaped identifiers, line/block comments,
  dollar strings, delimiters and inter-statement whitespace, multiline UTF-8 byte
  offsets, SQLite trigger bodies/CASE/keyword identifiers, DuckDB arrays and
  nested comments, and actionable no-query diagnostics for incomplete input.
- Real child Neovim tests invoke the command and actual mapping against SQLite
  and DuckDB, asserting the exact request and database effects. Existing
  whole-buffer execution remains available; empty/outside-editor actions do not
  send a request. The live-target integration test preserves TEMP data across
  refresh and uses the actual Session Adapter for lexical selection.
- Combined `make test` in daily-integration/dbridge.nvim passed all 152 cases,
  including 45 statement cases and 2 shared workflow cases, against the sibling
  integrated server. The standalone statement lane passed its 45 focused cases
  with `DBRIDGE_SERVER_CMD` pointing at that server's Python environment.
- Combined server `make check` passed mypy (48 files) and Ruff; `make test-cov`
  passed 350 tests on Python 3.12.12 with 98.71% coverage (85% floor).
- Strict OpenSpec validation, changed/new Markdown link checks, and whitespace
  checks passed before synchronization and archive. The shared contract now
  reflects the implemented EXPLAIN safety regression as well.

These are headless real-client tests, not interaction with a user's live Neovim.
The selector is lexical, not a general SQL validator or arbitrary procedural SQL
parser. The standalone feature depends on the companion Session workflow for
live per-Adapter edge cases; that dependency is verified in the combined tree.
