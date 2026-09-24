## 1. Edit flow

- [x] 1.1 Let `profiles.save` and `profiles.create_interactive` pass an optional `previous_name`, and make `explorer.handle_edit_profile` send the node's current name; verify with `tests/test_profiles.lua` that a save with `previous_name` over the protocol leaves only the new name in `dbridge/listProfiles`
- [x] 1.2 Apply node changes only after the server confirms and report the server's message on failure, leaving the node untouched; verify with a child-Neovim explorer test that renaming onto an existing Profile shows an error notification and both original nodes and definitions remain
- [x] 1.3 Verify with a child-Neovim test that renaming `old` to `new` leaves one `new` node, that reloading Profiles (panel rebuild) shows only `new`, and that editing config without renaming keeps one node

## 2. Connected Profiles

- [x] 2.1 Verify with a real-server test that renaming a connected, active Profile keeps its Session ID, updates the winbar Profile name, and still executes `SELECT 1` on that Session; fix the target descriptor only if the test shows a stale name

## 3. Documentation and closure

- [x] 3.1 Update the README `e` keymap description to say it edits or renames the Profile under the cursor and that renames need a server with `previous_name` support; update `docs/architecture.md` Profiles section to describe the single-request rename
- [x] 3.2 Run `make test` and lint with `DBRIDGE_SERVER_CMD` pointing at the paired server `rename-profiles-atomically` worktree; record the server revision and results here
- [x] 3.3 Validate with `openspec validate rename-profiles-atomically --strict`, sync the `profile-editing` spec, archive the change, and update roadmap outcome 1 to record Profile rename as implemented without marking the whole outcome complete

## Verification record

Verified on 2026-09-24 with Neovim 0.12.5 against the paired server worktree,
with the tested implementation committed as
`96c42a640b79f165f40c76877083fc7d156370de`. The server was explicitly selected
using `DBRIDGE_SERVER_CMD='<paired-server-worktree>/.venv/bin/python -m dbridge.server'`;
local paths and checkout baselines remain in the session handoff.

- `FILE=tests/test_profiles.lua make test_file`: 9 cases passed, including the
  wrapper's optional `previous_name` over the real protocol and unchanged upsert.
- `FILE=tests/test_profile_editing.lua make test_file`: 7 cases passed. The final
  full suite also verifies the corrected supported `uri` fixtures for DuckDB.
- `make test`: all 184 cases passed, zero failures or notes. Rerun after correcting
  the new fixtures and strengthening the same-name configuration edit assertion.
- Lua syntax validation through Neovim `loadfile` passed all 30 repository Lua
  files. Task 3.2's lint wording was reconciled with `docs/development.md`: no
  lint/format Makefile target or configuration exists, and no standalone style or
  static linter was run. No new lint dependency was introduced for this change.
- `openspec validate rename-profiles-atomically --strict`: passed before sync.
  Verified `profile-editing` requirements synchronized, all tasks completed, and
  the change archived; strict validation of all accepted specs also passed.
- `git diff --check` and explicit changed/new-file whitespace checks: passed.

The UI checks use real mounted panels and real server requests with isolated
Profile locations. They cover node identity, reload after panel rebuild,
same-name configuration replacement, collision preserving both Profiles and the
live Session, missing-source failure, and a delayed success callback proving the
node stays unchanged until confirmation. SQLite and DuckDB checks change both the
saved name and definition while retaining the connected adapter, Session ID,
temporary data, attached Scope Path, editor indicator, and editor-keymap
`SELECT 1` execution. The existing target descriptor required no change.

Lua syntax command:

```sh
nvim --headless -u NONE -l /dev/stdin <<'LUA'
local paths = vim.fn.globpath('.', '{lua,plugin,scripts,tests}/**/*.lua', false, true)
for _, path in ipairs(paths) do assert(loadfile(path)) end
print(('Lua syntax: %d files passed'):format(#paths))
LUA
```

Windows, other Neovim versions, and interactive GUI review were not run. The
linked server must ship first because older servers ignore `previous_name`.
UI-only rebuild Session lifetime remains the separately tracked client backlog
002; the reload check here uses an unconnected Profile.
