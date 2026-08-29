# AGENTS.md

Neovim plugin providing a database explorer, SQL editor, and results panel,
backed by the `dbridge` Python server over **stdio JSON-RPC 2.0** (LSP-style
`Content-Length` framing). The plugin spawns the server as a child process;
there is no HTTP and no port.

## Directory Overview

```
lua/dbridge/        ← plugin source (8 modules)
plugin/dbridge.lua  ← auto-loaded entry point; registers the nvim-cmp source
tests/              ← mini.test suite
scripts/            ← headless Neovim bootstrap for tests
deps/mini.nvim/     ← test dependency cloned by the Makefile (gitignored)
Makefile            ← test runner
TODO.md             ← deferred features
```

## Module Map

| File | Role |
|---|---|
| `lua/dbridge/init.lua` | nui layout, keymaps, `:Dbridge` command, plugin lifecycle |
| `lua/dbridge/client.lua` | stdio JSON-RPC transport: jobstart, framed read buffer, async + sync requests |
| `lua/dbridge/profiles.lua` | Profile CRUD over `dbridge/listProfiles`, `saveProfile`, `deleteProfile` |
| `lua/dbridge/explorer.lua` | Left-panel NuiTree; profiles and schema browsing; owns the active session |
| `lua/dbridge/editor.lua` | SQL editor panel; whole buffer or visual selection |
| `lua/dbridge/results.lua` | NuiTable results panel; client-side pagination |
| `lua/dbridge/cmp.lua` | nvim-cmp source backed by `dbridge/complete` |
| `lua/dbridge/cmp_format.lua` | Optional icon/label formatting for the cmp menu (public; documented in README) |

## Key Patterns

**Transport**: everything server-bound goes through `client.request(method,
params, cb)`, which is **asynchronous** — callbacks run on the event loop, so
wrap UI work in `vim.schedule`. `client.request_sync` exists for tests and
blocks via `vim.wait`. `client.start` returns `false` (and notifies) rather than
throwing when the server command is missing; `jobstart` raises E475 in that
case, so it is pre-checked with `vim.fn.executable`.

**Framing**: responses are reassembled in `client.lua`'s `on_stdout` against a
persistent `_buf`. Chunks arrive split arbitrarily, so never assume one event
carries one message.

**Sessions vs profiles**: a **Profile** is saved config owned by the server; a
**Session** is a live `session_id` returned by `dbridge/connect`. The plugin
holds session ids, never connection state. Profiles live only in the server's
`connections.toml` — do not read or write that file from Lua.

**No module globals**: modules return a table and are `require`d. The old client
set `DbExplorer`/`QueryEditor`/`Config` as Lua globals; that pattern is gone.

## Testing

`make test` runs the mini.test suite headless via `scripts/minimal_init.lua`.
It vendors `deps/mini.nvim` and `deps/nui.nvim` on first run.

Tests execute in a **child Neovim** (`MiniTest.new_child_neovim`), not in the
test process. This is not optional: the transport is async, so driving it needs
`vim.wait`, and a nested `vim.wait` re-enters MiniTest's own scheduler — one
file's hooks end up running another file's cases mid-request. `tests/child_env.lua`
runs inside the child and does all the blocking; the parent drives it over RPC
via `tests/helpers.lua`.

Every test spawns the **real** server. Each child gets its own
`XDG_CONFIG_HOME`, so `connections.toml` is throwaway and the developer's real
`~/.config/dbridge/` is never touched. Override the server argv with
`DBRIDGE_SERVER_CMD`.

| File | Covers |
|---|---|
| `tests/test_transport.lua` | framing across chunked reads, empty params, introspection, DSP error codes |
| `tests/test_profiles.lua` | profile CRUD, disk persistence, connect by profile name |
| `tests/test_results.lua` | column order, truncation, pagination, NULL vs empty, duplicate names |
| `tests/test_completion.lua` | cursor-aware completion, byte offsets, keyword fallback |
| `tests/test_lifecycle.lua` | mount, panel close, rebuild, DbridgeClose |

Add integration cases rather than stubbing `client.request`: every defect found
in Phase 2 was invisible at the unit level.

## Related

- Server repo: `../dbridge` — protocol surface, adapters, completion engine
- Phase 2 plan: `../dbridge/docs/superpowers/plans/2026-08-29-dbridge-phase-2-client-hardening.md`
- Glossary: `../dbridge/CONTEXT.md`
