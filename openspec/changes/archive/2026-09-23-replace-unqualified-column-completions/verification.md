# Verification

- Reproduction with the previous cmp.lua and a real nvim-cmp menu: both SQLite and
  DuckDB accepted `na|me` in `SELECT id, name FROM products` as `nameme`. Two new
  regression cases failed before the fix while the existing 14 cases passed.
- After the fix, `FILE=tests/test_cmp.lua make test_file`: 24 passed. New cases
  cover manual completion after commas, automatic typed prefixes, default Insert
  acceptance of existing suffixes, Unicode identifiers/text across lines, and the
  bare SELECT keyword menu. Existing qualified dot behavior remains covered.
- `make test`: all 66 cases passed across completion, transport, Profiles, results
  and lifecycle. The direct completion helper now honors the requested end-of-line
  byte position in Normal mode; old tests silently clamped left and the old server
  regex masked that mismatch. Table items still have no textEdit; the actual bare
  SELECT menu verifies keyword items have none either.
- Environment: Neovim 0.12.5, nvim-cmp revision `2ffe79f`, actual sibling dbridge
  worktree launched by uv with an isolated editable environment. Tests use
  temporary Profile directories and in-memory SQLite/DuckDB Sessions and stop
  child Neovim/server processes through existing hooks.
- Companion server `uv run --group test pytest --cov`: 315 passed, 98.62% total
  coverage. Completion-file mypy and focused ruff checks passed.
- Strict change/spec validation, `git diff --check`, and changed Markdown local
  link/whitespace checks were completed before archive.

README, architecture, development instructions and roadmap describe the verified
flow. Shared backlog 018/053 remain server-hosted; no duplicate local record was
created. The wire contract is unchanged and older servers remain compatible, but
new unqualified SELECT suggestions require the companion server. Vocabulary and
architectural boundaries are unchanged. No live user GUI, Windows isolation,
other Neovim versions, or new Lua lint tool were exercised. No commits, pushes or
releases were made, and the unrelated documentation migration remains untouched.
