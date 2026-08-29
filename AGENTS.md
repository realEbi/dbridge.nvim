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

`make test` runs mini.test headless via `scripts/minimal_init.lua`. Tests that
touch profiles must point the server at a temp `connections.toml` via its
`dbridge_`-prefixed env so they never mutate `~/.config/dbridge/`.

## Related

- Server repo: `../dbridge` — protocol surface, adapters, completion engine
- Phase 2 plan: `../dbridge/docs/superpowers/plans/2026-08-29-dbridge-phase-2-client-hardening.md`
- Glossary: `../dbridge/CONTEXT.md`
