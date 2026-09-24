## 1. Transport test

- [x] 1.1 In `tests/test_transport.lua`, replace the `primary_keys` assertion with `primary_key` equal to `{ name = vim.NIL, columns = { "id" } }` (or the decoded null the helpers produce) and assert that `primary_keys` is absent; verify the test passes with `DBRIDGE_SERVER_CMD` pointing at the paired `extract-table-key-constraints` server worktree and fails against the current `dbridge-2.0` server
- [x] 1.2 Confirm with `rg -n 'primary_keys|foreign_keys' lua plugin tests` that no other client code or test reads the old fields

## 2. Verification and closure

- [x] 2.1 Run `make test` and the repository's lint check with the paired server; record the server revision and results here
- [x] 2.2 Check `docs/development.md` for any statement about the minimum server revision the tests need and update it if present; validate with `openspec validate adopt-table-key-constraints --strict`, archive the change, and update the roadmap outcome 1 text only if it lists DuckDB constraints

## Verification record

Verified on 2026-09-24 with Neovim 0.12.5. Both focused runs explicitly selected
their real server executable through `DBRIDGE_SERVER_CMD` and used the normal
child-Neovim harness with isolated Profile configuration.
The positive runs used the paired `extract-table-key-constraints` worktree based
on `c66a21aa721e94462472614f4edca541cbf4318c` with the applied server change,
committed as [`1b294825058da0ce150c5e913c5d957c777863ce`](https://github.com/realEbi/dbridge/commit/1b294825058da0ce150c5e913c5d957c777863ce).
The committed runtime source matches the source used by both positive runs.

- Negative control: `FILE=tests/test_transport.lua make test_file` against the
  pre-change server `c66a21aa721e94462472614f4edca541cbf4318c` failed exactly the
  `listTables and getTableSchema` case: `schema.primary_key` was nil instead of
  the expected object. The remaining 11 cases passed. This is the intended
  compatibility failure, not an unresolved defect.
- Positive focused check: the same command with the paired
  `extract-table-key-constraints` server worktree passed all 12 cases, zero notes.
- `make test` with
  `DBRIDGE_SERVER_CMD='<paired-server-worktree>/.venv/bin/python -m dbridge.server'`:
  all 184 cases passed, zero failures or notes.
- `rg -n 'primary_keys|foreign_keys' lua plugin tests` found only the assertion
  that `primary_keys` is absent. No runtime consumer or additional test migration
  was required.
- Lua syntax validation through Neovim `loadfile` passed all 30 repository Lua
  files. There is no repository lint/format target or configured static linter;
  no standalone lint check or new lint dependency was added.
- `openspec validate adopt-table-key-constraints --strict` and `git diff --check`
  passed before archive. The change was archived on 2026-09-24 with all tasks
  verified; final strict validation passed all accepted specs. `skip_specs: true`
  remains intentional because this changes integration verification without a
  client capability change.

`docs/development.md` now records the required linked server change. Roadmap
outcome 1 does not list DuckDB constraints, so its text remains unchanged.

Lua syntax validation command:

```sh
nvim --headless -u NONE -l /dev/stdin <<'LUA'
local paths = vim.fn.globpath('.', '{lua,plugin,scripts,tests}/**/*.lua', false, true)
for _, path in ipairs(paths) do assert(loadfile(path)) end
print(('Lua syntax: %d files passed'):format(#paths))
LUA
```

No Windows or interactive GUI run was performed. The test intentionally rejects
the old metadata field shape; client production code is unchanged.
