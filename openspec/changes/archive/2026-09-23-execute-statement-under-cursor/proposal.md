## Why

Normal execution currently sends the whole query buffer. Working with several
queries requires repeatedly selecting text manually; server backlog 006 requests
a command to execute the statement containing the cursor.

## What Changes

- Add `:DbridgeExecuteStatement` and normal-mode `<leader>s` in the query editor.
- Identify statement boundaries without splitting SQL strings, quoted identifiers,
  comments, or SQLite trigger bodies at their internal semicolons.
- Preserve existing whole-buffer and visual-selection `<leader>r` behavior.
- Define whitespace, delimiter, empty-input, and incomplete-input behavior and
  verify the command against real SQLite and DuckDB Sessions.

## Capabilities

### New Capabilities

- `statement-execution`: Selecting and executing the query-buffer statement at
  the cursor while preserving existing execution actions.

### Modified Capabilities

None. SQL completion remains a separate contract.

## Impact

Owner: dbridge.nvim editor interaction and tests. Existing `dbridge/execute`
handles the selected SQL; no server or DSP changes are needed. Related server
backlog [006](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/006-statement-under-cursor.md),
client roadmap reusable and precisely selected SQL. Multi-result execution,
transaction controls, arbitrary procedural SQL parsing, and saved queries are
separate outcomes. No runtime parser dependency is introduced.
