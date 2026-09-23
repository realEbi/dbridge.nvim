## Context

See proposal.md for the reported failure. The source already sends full SQL and
byte offsets asynchronously and suppresses stale replies. Existing tests call the
source directly, bypassing nvim-cmp's trigger and acceptance behavior. The server
remains synchronous; this change does not alter process or Session ownership.

## Goals / Non-Goals

Keep database semantics in the companion server change and editor edits here.
No new DSP fields, user mappings, or runtime dependencies are required.

## Decisions

- Register `.` through nvim-cmp's source trigger interface; retain users' existing
  automatic-completion settings rather than forcing the popup from an autocmd.
- Capture the current post-dot identifier range before the asynchronous request.
  Supply a plain `textEdit` for returned columns, including the suffix after the
  cursor. `insertText` alone can duplicate that suffix with default Insert behavior;
  changing the user's global confirmation mode would affect unrelated sources.
- Declare UTF-8 position encoding for edits, matching Neovim cursor bytes and
  DSP offsets. Use Neovim keyword characters to include multibyte identifiers
  and recognize whitespace across lines between dot and identifier. Preserve
  bare server labels and insertion strings.
- Add nvim-cmp to development dependencies and drive actual child-Neovim typing
  and confirmation against the real server. Direct source tests remain useful
  for response mapping but cannot establish automatic menu behavior.

## Risks / Trade-offs

- An older server cannot resolve aliases → document that both fixes are needed;
  existing wire shapes and unqualified behavior remain compatible.
- Cursor ranges can be corrupted by multibyte text or existing suffixes → verify
  exact resulting SQL through real nvim-cmp default Insert acceptance.
- This does not add CTE/derived-column inference → retain the server's documented
  limits and backlog ownership. No architectural decision is superseded.

## Migration Plan

Use the updated client and server, restart Neovim, and reconnect the Profile.
Local checkout users can use the documented `server_cmd` override. No database or
Profile migration is needed; reverting the source restores prior behavior.
