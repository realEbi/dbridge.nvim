# DBridge.nvim

A Neovim plugin for [dbridge](https://github.com/realebi/dbridge) to interact with
different databases inside Neovim, using [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

The plugin spawns the dbridge server as a child process and talks to it over
**stdio JSON-RPC 2.0** with LSP-style `Content-Length` framing. There is no HTTP
server to start and no port to configure.

The Lua client sends requests asynchronously; the current Python server handles
them sequentially. See [current architecture](docs/architecture.md) for that
boundary and [roadmap](docs/roadmap.md) for proposed future work.

![Screenshot](assets/mysql-employees.png)

## Table of contents

- [Installation](#installation)
- [Usage](#usage)
- [Profiles](#profiles)
- [Autocompletion](#autocompletion)
- [Documentation](#documentation)
- [Development](#development)
- [License](#license)

## Installation

**Requires nvim >= 0.10.**

Install the [dbridge](https://github.com/realebi/dbridge) server so its `dbridge`
console script is on your `PATH`:

```bash
pip install dbridge
```

- lazy.nvim:

  ```lua
  {
    "realebi/dbridge.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("dbridge").setup()
    end,
  },
  ```

- packer.nvim:

  ```lua
  use {
    "realebi/dbridge.nvim",
    requires = {
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("dbridge").setup()
    end
  }
  ```

### Pointing at a different server

`setup()` takes `server_cmd`, the argv used to spawn the server. It defaults to
`{ "dbridge" }`. Override it when the server lives in a virtualenv or a local
checkout rather than on your `PATH`:

```lua
require("dbridge").setup({
  server_cmd = { "uv", "run", "--directory", "/path/to/dbridge", "python", "-m", "dbridge.server" },
})
```

If the command is not executable, the plugin reports that instead of opening.

## Usage

Run `:Dbridge` to open the UI in a new tab (`:DbridgeClose` closes it and
stops the server): a profile/schema explorer on the
left, a SQL editor and a results panel on the right. Run `:Dbridge` again to
hide it, or `gt` to switch tabs.

Explorer tree:

- `a` — add a profile
- `e` — edit the profile under the cursor
- `<CR>` — open a profile / database / schema / table
- `DD` — delete the profile under the cursor
- `R` — refresh schema for the node under the cursor, preserving its live Session
- `l` / `h` — expand and collapse a node

Entering a table loads its metadata, then generates a sample SELECT using the
server's quoted identifier. This preserves the selected SQLite namespace or DuckDB
catalog/schema, including names with spaces, quotes, or dots. Metadata failures
show an error without running a guessed query. Update both server and client for
this behavior; a successful older-server response without an identifier retains
legacy bare-name queries and their ambiguity/unusual-name limits.

Editor and results panels:

- `<leader>r` — run the buffer, or the visual selection, as a query
- `n` / `p` — next / previous page of results

The query editor's top bar shows the active Profile, adapter, and Session ID used
for execution and completion. While the explorer is focused, its connected
Profile under the cursor is the target; in the editor, the last interacted
connected Profile is used, falling back to another connected Profile. With no
live target, the bar says `No active Session`.

Schema refresh keeps the same Session, including in-memory data and temporary
tables. Metadata is replaced after a successful refresh; if refresh or listing
fails, the previous tree remains visible and the error is reported.

## Profiles

Profiles are named database configurations owned by the **server**. Its
`connections.toml` lives in `$XDG_CONFIG_HOME/dbridge` (default
`~/.config/dbridge`) on Unix-like systems, or `%APPDATA%\dbridge` on Windows.
The plugin never reads or writes the file directly — it goes through
`dbridge/listProfiles`, `dbridge/saveProfile`, and `dbridge/deleteProfile`.
See the [server Profile documentation](https://github.com/realEbi/dbridge/blob/dbridge-2.0/README.md#profiles)
for storage details.

Press `a` in the explorer and you will be prompted for a name, an adapter, and a
JSON config blob. The config keys depend on the adapter, for example:

```json
{ "uri": "/path/to/db.sqlite" }
```

Supported adapters are whatever the server registers — currently `sqlite` and
`duckdb`.

## Autocompletion

Completion is served by the server over `dbridge/complete` and exposed as an
[nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source named `dbridge`, which
registers itself when nvim-cmp is present. It activates in `sql` buffers while a
server is running.

```lua
return {
  'hrsh7th/nvim-cmp',
  event = 'InsertEnter',
  config = function()
    local cmp = require 'cmp'
    cmp.setup.filetype({ 'sql' }, {
      sources = {
        { name = 'dbridge' },
      },
    })
  end,
}
```

### Menu labels

nvim-cmp shows the generic LSP kind, so a table reads as `Class` and a column as
`Field`. `dbridge.cmp_format` maps those back to dbridge's own vocabulary
(`table`, `column`, `keyword`) with icons. It is optional:

```lua
cmp.setup {
  formatting = {
    format = function(entry, vim_item)
      if entry.source.name == 'dbridge' then
        return require('dbridge.cmp_format').build_format(entry, vim_item)
      end
      return vim_item
    end,
  },
}
```

Completion is cursor-aware: the whole buffer is sent along with the cursor's
byte offset, so a `SELECT` on one line resolves columns from a `FROM` on
another.

With automatic completion enabled and an active Session, typing `.` after a
table alias opens column suggestions. For example, in
`SELECT p.name, p.category FROM products p LIMIT 100`, complete after either
`p.`. Typing `p.na` filters to matching columns; accepting `name` inserts
`p.name`, including when editing inside an existing column name.

Unqualified SELECT targets also offer columns with a supporting server: request
completion after the comma in `SELECT id, name FROM products`, or type `na` at
an empty target. Accepting a column replaces its whole identifier, including any
suffix after the cursor. A bare `SELECT ` displays the server's dialect keywords.

These suggestions require the corresponding server completion support. When
testing local changes, use the [server command override](#pointing-at-a-different-server),
restart Neovim, and reconnect the Profile. CTE and derived-table column inference
remain server limitations.

## Documentation

- [Domain language](CONTEXT.md) — client terms and shared vocabulary
- [Current architecture](docs/architecture.md) — implemented behavior and limits
- [Roadmap](docs/roadmap.md) — proposed future outcomes and dependencies
- [Backlog](docs/backlog/README.md) — deferred ideas, defects, and questions
- [Agent workflow](AGENTS.md) — which documents to read and update
- [OpenSpec changes](openspec/changes/) and [capability specs](openspec/specs/) — active work and accepted contracts

## Development

See the [development guide](docs/development.md) for prerequisites, test commands,
the real-server integration harness, and the OpenSpec workflow. It owns the
server-command override and test-isolation instructions.

## License

`dbridge.nvim` is distributed under the terms of the [MIT](https://spdx.org/licenses/MIT.html) license.
