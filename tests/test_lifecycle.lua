-- UI lifecycle. Guards the BufUnload re-entry that used to hang Neovim.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

-- A fresh child per case: these tests mount, tear down, and remount the UI, so
-- leaked window state between them would be misleading.
local T = MiniTest.new_set({
  hooks = {
    pre_case = function() H.boot(child, { ui = true }) end,
    post_case = function() H.shutdown(child) end,
  },
})

T[":Dbridge mounts three panels"] = function()
  eq(child.lua_get("#vim.api.nvim_tabpage_list_wins(0)"), 3)
  eq(child.lua_get("vim.g.dbridge_loaded"), 1)
  eq(child.lua_get("require('dbridge.client').is_running()"), true)
  for _, panel in ipairs({ "explorer", "editor", "results" }) do
    eq(child.lua_get(("require('dbridge.%s').panel.winid ~= nil"):format(panel)), true)
  end
end

-- Regression: closing one panel used to re-enter open() forever. If this
-- regresses the child stops responding and the case fails on timeout rather
-- than hanging the whole run.
T["closing one panel tears down without hanging"] = function()
  child.lua("vim.api.nvim_buf_delete(require('dbridge.editor').panel.bufnr, { force = true })")
  eq(child.lua_get("_E.wait_for(function() return vim.g.dbridge_loaded == 0 end, 5000)"), true)
  -- the child is still responsive
  eq(child.lua_get("1 + 1"), 2)
end

T[":Dbridge rebuilds a working layout after a close"] = function()
  child.lua("vim.api.nvim_buf_delete(require('dbridge.editor').panel.bufnr, { force = true })")
  child.lua_get("_E.wait_for(function() return vim.g.dbridge_loaded == 0 end, 5000)")

  child.lua("vim.cmd('Dbridge')")
  eq(child.lua_get("vim.g.dbridge_loaded"), 1)
  eq(child.lua_get("#vim.api.nvim_tabpage_list_wins(0)"), 3)

  -- and it still serves queries
  local sid = child.lua_get("_E.connect_memory()")
  child.lua("_E.exec(...)", { sid, "CREATE TABLE after_reopen (id INTEGER)" })
  eq(H.request(child, "dbridge/listTables", { session_id = sid }), { "after_reopen" })
end

T["saved profiles populate the explorer on open"] = function()
  child.lua_get("_E.profile_call(...)", { "save", "seeded", "sqlite", { uri = ":memory:" } })

  -- reopen the UI and expect the profile to come back from disk
  child.lua("_E.shutdown()")
  child.lua("require('dbridge').setup(...)", { { server_cmd = H.server_cmd() } })
  child.lua("vim.cmd('Dbridge')")

  eq(child.lua_get(
    "_E.wait_for(function() return #require('dbridge.explorer').tree:get_nodes() > 0 end, 15000)"
  ), true)
  local names = child.lua_get(
    "vim.tbl_map(function(n) return n._name end, require('dbridge.explorer').tree:get_nodes())"
  )
  eq(vim.tbl_contains(names, "seeded"), true)
end

T["DbridgeClose stops the server"] = function()
  eq(child.lua_get("require('dbridge.client').is_running()"), true)
  child.lua("vim.cmd('DbridgeClose')")
  eq(child.lua_get("vim.g.dbridge_loaded"), 0)
  eq(child.lua_get("_E.wait_for(function() return not require('dbridge.client').is_running() end, 5000)"), true)
end

return T
