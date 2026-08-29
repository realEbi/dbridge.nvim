# DBridge.nvim

A Neovim plugin for [dbridge](https://github.com/realebi/dbridge) to interact with
different databases inside Neovim, using [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

The plugin spawns the dbridge server as a child process and talks to it over
**stdio JSON-RPC 2.0** with LSP-style `Content-Length` framing. There is no HTTP
server to start and no port to configure.

![Screenshot](assets/mysql-employees.png)

## Table of contents

- [Installation](#installation)
- [Usage](#usage)
- [Connection profiles](#connection-profiles)
- [Autocompletion](#autocompletion)
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
- `R` — refresh schema for the node under the cursor
- `l` / `h` — expand and collapse a node

Editor and results panels:

- `<leader>r` — run the buffer, or the visual selection, as a query
- `n` / `p` — next / previous page of results

## Connection profiles

Profiles are named database configurations owned by the **server** and stored in
`~/.config/dbridge/connections.toml`. The plugin never reads or writes that file
directly — it goes through `dbridge/listProfiles`, `dbridge/saveProfile`, and
`dbridge/deleteProfile`.

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

Completion is cursor-aware: the whole buffer is sent along with the cursor's
byte offset, so a `SELECT` on one line resolves columns from a `FROM` on
another.

## Development

Tests use [mini.test](https://github.com/nvim-mini/mini.nvim) and run headless:

```bash
make test              # all tests (clones deps/mini.nvim on first run)
FILE=tests/test_basic.lua make test_file
```

## License

`dbridge.nvim` is distributed under the terms of the [MIT](https://spdx.org/licenses/MIT.html) license.
