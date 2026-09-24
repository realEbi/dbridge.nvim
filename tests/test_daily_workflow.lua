-- Verify the boundary between live Session metadata and statement selection.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

for _, adapter in ipairs({ "sqlite", "duckdb" }) do
  local child = MiniTest.new_child_neovim()
  local config_dir
  T[adapter] = MiniTest.new_set({ hooks = {
    pre_case = function() config_dir = H.boot(child, { ui = true }) end,
    post_case = function()
      H.shutdown(child)
      vim.fn.delete(config_dir, "rf")
    end,
  } })
  T[adapter]["refresh and cursor execution use the live target Adapter"] = function()
    local result = child.lua_get([[(function(adapter)
      local explorer = require('dbridge.explorer')
      local editor = require('dbridge.editor')
      local config = adapter == 'sqlite' and { uri = ':memory:' } or { database = ':memory:' }
      assert(_E.profile_call('save', 'daily', adapter, config).result)
      local n = explorer.add_profile_node('daily', adapter, config)
      local function focus()
        vim.api.nvim_set_current_win(explorer.panel.winid)
        local _, row = explorer.tree:get_node(n:get_id())
        vim.api.nvim_win_set_cursor(0, { assert(row), 0 })
      end
      focus()
      explorer.handle_enter()
      assert(_E.wait_for(function() return n._session_id and #n:get_child_ids() > 0 end, 15000))
      local sid = n._session_id
      _E.exec_many(sid, {
        'CREATE TEMP TABLE markers ("a;b" TEXT)',
        "INSERT INTO markers VALUES ('kept')",
      })
      local previous = explorer.tree:get_node(n:get_child_ids()[1])
      explorer.handle_refresh()
      assert(_E.wait_for(function()
        return explorer.tree:get_node(n:get_child_ids()[1]) ~= previous
      end, 15000))
      assert(sid == n._session_id)
      vim.api.nvim_set_current_win(editor.panel.winid)
      local target = explorer.get_active_target()
      assert(target.adapter == adapter and target.session_id == sid)
      local query = adapter == 'sqlite' and 'SELECT [a;b] AS value FROM markers;'
        or "SELECT ['a];b'][1] AS value FROM markers;"
      editor.set_sql(query .. "\nSELECT 'wrong';")
      vim.api.nvim_win_set_cursor(0, { 1, 10 })
      local results = require('dbridge.results')
      local original = results.render
      local got
      results.render = function(r) got = r; original(r) end
      vim.cmd('DbridgeExecuteStatement')
      assert(_E.wait_for(function() return got ~= nil end, 10000))
      return { rows = got.rows, target = target.adapter, sid_preserved = sid == n._session_id }
    end)(...)]], { adapter })
    eq(result, { rows = { { adapter == "sqlite" and "kept" or "a];b" } }, target = adapter, sid_preserved = true })
  end
end

return T
