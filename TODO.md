# Deferred Features

## Saved Queries

The old dbridge.nvim client had a "Saved queries" node per connection in the explorer tree,
backed by SQL files stored at `~/.local/share/nvim/dbridge.nvim/queries/<connection>/`.

### What it did
- "Saved queries" tree node per connection, lazy-loaded
- `<CR>` on a "New query" node → created a timestamped `.sql` file and opened it in the editor
- `<CR>` on a saved query node → opened the file in the editor
- `DD` on a saved query node → deleted the file from disk
- Query file names: `<connection>-<table>-<timestamp>.sql`

### Implementation notes for when you pick this up
- Add `NodeType.SAVED_QUERY` and `NodeType.ROOT_SAVED_QUERY` to explorer.lua
- Store queries at `vim.fn.stdpath("data") .. "/dbridge.nvim/queries/<connection_name>/"`
- On connection expand, add a "Saved queries" child node with lazy-loaded `.sql` files
- Bind `<CR>` on saved-query nodes to open the file in editor.lua's buffer
- No server changes needed — this is pure client-side file management
