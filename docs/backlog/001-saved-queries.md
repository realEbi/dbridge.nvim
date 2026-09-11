# 001 - Save and browse reusable SQL queries

- Repo: dbridge.nvim
- Status: deferred
- Change: none
- Origin: Retired `TODO.md` at revision `1cea404`; related server backlog item 007.

## Problem / opportunity

The current explorer has no saved-query browser. The legacy client supported SQL
files grouped by what it called a connection (a Profile in current terminology).
Preserve that useful intent without treating the retired implementation notes as
a design for the current modules.

## Desired outcome

Provide a Profile's lazily loaded saved-query list with create, open, and delete
actions. Opening a saved query or creating a new one places its SQL in the editor.
This can be client-owned file management; no server change is assumed necessary.
Define how Profile rename/deletion affects stored queries before implementation.

## Notes and references

Historical behavior and suggestions retained from the
[original document](https://github.com/realEbi/dbridge.nvim/blob/1cea404/TODO.md):

- A "Saved queries" node under each Profile, populated lazily when expanded.
- `<CR>` on a "New query" node created a timestamped `.sql` file and opened it
  in the editor; `<CR>` on an existing query opened that file.
- `DD` on a saved-query node deleted the file from disk.
- Legacy location: `~/.local/share/nvim/dbridge.nvim/queries/<connection>/`.
  The suggested portable base was `vim.fn.stdpath("data")`, with the suffix
  `/dbridge.nvim/queries/<connection_name>/`.
- Legacy filename convention: `<connection>-<table>-<timestamp>.sql`.
- The old suggestion to add `NodeType.SAVED_QUERY` and `NodeType.ROOT_SAVED_QUERY`
  is historical; those constants are not part of the current explorer. Recheck
  [explorer.lua](../../lua/dbridge/explorer.lua) and
  [editor.lua](../../lua/dbridge/editor.lua) before choosing the new integration.

Related provenance: [server backlog 007](https://github.com/realEbi/dbridge/blob/dbridge-2.0/docs/backlog/007-saved-queries.md).
Storage paths, naming, migration, and destructive-action behavior remain choices
for a future proposal. This migration did not restore the feature.
