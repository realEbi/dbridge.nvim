## Context and ownership

cmp.lua sends full SQL and a UTF-8 byte position and translates the server's
unchanged completion items. It currently supplies a textEdit only when a dot
precedes the word. The server now resolves unqualified SELECT columns, so the
same default Insert behavior that previously duplicated qualified suffixes also
affects these suggestions. The Client owns this replacement; the companion
server change owns source inference and keyword fallback. No architectural
boundary or execution-model decision changes; there are no client ADRs to supersede.

## Decisions

Compute the current line's identifier range with the same Neovim keyword matching
already used by the qualified path, independently of a dot. Capture the byte
range before the asynchronous RPC and use it only for returned column items.
Keep get_position_encoding_kind as UTF-8, the full-buffer byte offset, request
sequence suppression, and dot triggering unchanged. The full word includes its
right-hand suffix, so Insert acceptance replaces it rather than appending twice.
Table and keyword items retain their existing mapping and insertion policy.

This also covers a qualified identifier on a later line than its dot because the
replacement range belongs solely to the current identifier. Quoted/derived source
inference remains server work. General ranking and keyword patterns are unchanged.

## Verification and compatibility

Use the existing real nvim-cmp child-Neovim harness and both in-memory SQLite and
DuckDB Sessions. First reproduce unqualified midword duplication. Then verify
empty/comma targets, automatic typed-prefix suggestions, manual midword completion,
Unicode text/identifiers across lines, and the server's bare SELECT keyword menu.
Run the whole client suite and the companion server's coverage gate. Existing
servers remain wire-compatible; new SELECT behavior requires the updated server.

## Verification discovery

The existing direct source helper set end-of-line positions in Normal mode, where
Neovim silently clamped the cursor one byte left. The legacy server regex hid the
mismatch. Direct checks now enable `virtualedit=onemore` in their test window so
the requested byte offset matches actual Insert-mode completion; runtime editor
options are unchanged. Automatic prefix tests type separate keystrokes so nvim-cmp
receives normal edit events rather than a batched synthetic input event.
