-- Real-server checks for the linked async-orchestration contract.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local slow_queries = {
  sqlite = "WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x + 1 FROM n) SELECT sum(x) FROM n",
  duckdb = "SELECT sum(hash(i)) FROM range(20000000000) t(i)",
}

for _, adapter in ipairs({ "sqlite", "duckdb" }) do
  local child = MiniTest.new_child_neovim()
  local A = MiniTest.new_set({ hooks = {
    pre_case = function()
      H.boot(child, { ui = true })
      local connected, err = H.request(child, "dbridge/connect", { adapter = adapter, config = { uri = ":memory:" } })
      eq(err, nil)
      child.lua([[
        local sid, adapter = ...
        C = { sid = sid, replies = {}, notifications = {} }
        _E.stub_active_session(sid)
        require('dbridge.explorer').get_active_target = function()
          return { name = 'cancel', adapter = adapter, dialect = adapter, session_id = sid, path = _E.sessions[sid].default_path }
        end
        local client = require('dbridge.client')
        local request = client.request
        client.request = function(method, params, callback)
          local id
          id = request(method, params, function(result, failure)
            if method == 'dbridge/execute' then C.replies[id] = { result = result, err = failure } end
            callback(result, failure)
          end)
          return id
        end
        vim.notify = function(message, level)
          table.insert(C.notifications, { message = message, level = level })
        end
        local results = require('dbridge.results')
        local render = results.render
        results.render = function(result) C.rendered = result; render(result) end
        function C.submit(sql)
          local editor = require('dbridge.editor')
          vim.api.nvim_set_current_win(editor.panel.winid)
          editor.set_sql(sql)
          vim.api.nvim_win_set_cursor(editor.panel.winid, { 1, 0 })
          vim.cmd('DbridgeExecuteStatement')
        end
        function C.wait_cancelled()
          return vim.wait(10000, function()
            for _, note in ipairs(C.notifications) do
              if note.message == '[dbridge] query cancelled' then return true end
            end
            return false
          end, 10)
        end
      ]], { connected.session_id, adapter })
    end,
    post_case = function() H.shutdown(child) end,
  } })
  T[adapter] = A

  A["cancel command preserves results and the live Session"] = function()
    child.lua([[
      C.submit('SELECT 7 AS previous')
      assert(vim.wait(5000, function() return C.rendered ~= nil end, 10))
      C.notifications = {}
    ]])
    local previous_lines = child.lua_get("vim.api.nvim_buf_get_lines(require('dbridge.results').panel.bufnr, 0, -1, false)")
    child.lua("C.submit(...); _E.settle(100); vim.cmd('DbridgeCancel')", { slow_queries[adapter] })
    eq(child.lua_get("C.wait_cancelled()"), true)
    eq(child.lua_get("C.notifications[#C.notifications]"), {
      message = "[dbridge] query cancelled", level = child.lua_get("vim.log.levels.INFO"),
    })
    eq(child.lua_get("vim.api.nvim_buf_get_lines(require('dbridge.results').panel.bufnr, 0, -1, false)"), previous_lines)
    eq(child.lua_get("_E.exec(C.sid, 'SELECT 42 AS reused').rows"), { { 42 } })
    child.lua("vim.cmd('DbridgeCancel')")
    eq(child.lua_get("C.notifications[#C.notifications].message"), "[dbridge] no outstanding query")
  end

  if adapter == "duckdb" then
    A["completion overtakes a query which can then be cancelled"] = function()
      child.lua([[
        _E.exec(C.sid, 'CREATE TABLE people (name VARCHAR)')
        C.replies = {}
      ]])
      child.lua("C.submit(...); _E.settle(100)", { slow_queries.duckdb })
      local completion = child.lua_get("_E.complete_at({ 'SELECT p.na FROM people p' }, 1, 11)")
      eq(completion.done, true)
      eq(vim.tbl_contains(completion.labels, "name"), true)
      eq(child.lua_get("vim.tbl_count(C.replies)"), 0)
      child.lua("vim.cmd('DbridgeCancel')")
      eq(child.lua_get("C.wait_cancelled()"), true)
      eq(child.lua_get("_E.exec(C.sid, 'SELECT 3').rows"), { { 3 } })
    end
  end
end

return T
