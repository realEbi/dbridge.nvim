-- Parent-side helpers. Tests run against a child Neovim so that the blocking
-- waits an async transport needs cannot re-enter MiniTest's own scheduler.
local H = {}

--- argv used to spawn the server. Override with DBRIDGE_SERVER_CMD in CI.
function H.server_cmd()
  local override = vim.env.DBRIDGE_SERVER_CMD
  if override and override ~= "" then
    return vim.split(override, "%s+", { trimempty = true })
  end
  local sibling = vim.fn.fnamemodify(vim.fn.getcwd() .. "/../dbridge", ":p"):gsub("/$", "")
  return { "uv", "run", "--directory", sibling, "python", "-m", "dbridge.server" }
end

--- Start a child Neovim with the plugin loaded and a server running.
--- Each child gets its own XDG_CONFIG_HOME, so connections.toml is throwaway.
function H.boot(child, opts)
  opts = opts or {}
  local config_dir = vim.fn.tempname()
  vim.fn.mkdir(config_dir, "p")

  child.restart({ "-u", "scripts/child_init.lua" })
  child.lua("_E = require('tests.child_env')")
  child.lua("_E.boot(...)", {
    { config_dir = config_dir, server_cmd = H.server_cmd(), ui = opts.ui or false },
  })
  return config_dir
end

function H.shutdown(child)
  pcall(function() child.lua("_E.shutdown()") end)
  child.stop()
end

--- Call a function on the child's _E table and return its value.
function H.call(child, expr, args)
  return child.lua_get("_E." .. expr, args)
end

--- Unwrap the {result, err} envelope the child returns for requests.
function H.request(child, method, params, timeout)
  local r = child.lua_get("_E.request(...)", { method, params or vim.empty_dict(), timeout })
  if r.err == false then r.err = nil end
  return r.result, r.err
end

return H
