-- Live Session preservation and the target shown in the query editor.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local config_dir

local T = MiniTest.new_set({ hooks = {
  pre_case = function()
    config_dir = H.boot(child, { ui = true })
    child.lua([[
      _S = {}
      _S.explorer = require('dbridge.explorer')
      _S.editor = require('dbridge.editor')
      _S.client = require('dbridge.client')
      function _S.focus(n)
        vim.api.nvim_set_current_win(_S.explorer.panel.winid)
        local _, row = _S.explorer.tree:get_node(n:get_id())
        vim.api.nvim_win_set_cursor(_S.explorer.panel.winid, { assert(row), 0 })
        vim.cmd('doautocmd CursorMoved')
      end
      function _S.connect(name, adapter)
        adapter = adapter or 'sqlite'
        local config = adapter == 'sqlite' and { uri = ':memory:' } or { database = ':memory:' }
        assert(_E.profile_call('save', name, adapter, config).result)
        local n = _S.explorer.add_profile_node(name, adapter, config)
        _S.focus(n)
        _S.explorer.handle_enter()
        assert(_E.wait_for(function() return n._session_id and #n:get_child_ids() > 0 end, 15000))
        return n
      end
      function _S.tables(n)
        local out = {}
        local function visit(parent)
          for _, item in ipairs(_S.explorer.tree:get_nodes(parent:get_id())) do
            if item._type == 'table' then out[#out + 1] = item._table end
            visit(item)
          end
        end
        visit(n)
        table.sort(out)
        return out
      end
      function _S.refresh(n, expected)
        _S.focus(n)
        local previous = _S.explorer.tree:get_node(n:get_child_ids()[1])
        _S.explorer.handle_refresh()
        assert(_E.wait_for(function()
          return _S.explorer.tree:get_node(n:get_child_ids()[1]) ~= previous
            and vim.tbl_contains(_S.tables(n), expected)
        end, 15000))
      end
      function _S.bar()
        return vim.api.nvim_get_option_value('winbar', { win = _S.editor.panel.winid })
      end
      function _S.edit()
        vim.api.nvim_set_current_win(_S.editor.panel.winid)
        vim.cmd('doautocmd WinEnter')
      end
    ]])
  end,
  post_case = function()
    H.shutdown(child)
    vim.fn.delete(config_dir, "rf")
  end,
} })

for _, adapter in ipairs({ "sqlite", "duckdb" }) do
  T[adapter .. " refresh preserves memory data and temporary state"] = function()
    local r = child.lua_get([[(function(adapter)
      local n = _S.connect('memory', adapter)
      local sid = n._session_id
      _E.exec_many(sid, {
        'CREATE TABLE kept (value INTEGER)', 'INSERT INTO kept VALUES (42)',
        'CREATE TEMP TABLE scratch (value INTEGER)', 'INSERT INTO scratch VALUES (7)',
      })
      local methods, request = {}, _S.client.request
      _S.client.request = function(method, params, callback)
        methods[#methods + 1] = method
        request(method, params, callback)
      end
      _S.refresh(n, 'kept')
      _S.refresh(n, 'kept')
      _S.edit()
      return { sid == n._session_id, _S.explorer.get_active_session() == sid,
        _E.exec(sid, 'SELECT value FROM kept').rows,
        _E.exec(sid, 'SELECT value FROM scratch').rows,
        vim.tbl_contains(methods, 'dbridge/connect'), vim.tbl_contains(methods, 'dbridge/disconnect'),
        _S.bar():find(sid, 1, true) ~= nil }
    end)(...)]], { adapter })
    eq(r, { true, true, { { 42 } }, { { 7 } }, false, false, true })
  end
end

for _, method in ipairs({ "refreshSchema", "listDatabases", "listSchemas", "listTables" }) do
  T[method .. " failure retains metadata and target"] = function()
    local r = child.lua_get([[(function(method)
      local n = _S.connect('memory', method == 'listSchemas' and 'duckdb' or 'sqlite')
      local sid = n._session_id
      _E.exec(sid, 'CREATE TABLE kept (value INTEGER)')
      _S.refresh(n, 'kept')
      local request = _S.client.request
      _S.client.request = function(name, params, callback)
        if name == 'dbridge/' .. method then
          vim.schedule(function() callback(nil, { message = 'intentional listing failure' }) end)
        else request(name, params, callback) end
      end
      _E.take_notifications()
      _S.explorer.handle_refresh()
      assert(_E.wait_for(function() return #_E.notifications > 0 end))
      return { n._session_id == sid, _S.tables(n),
        _S.explorer.get_active_session() == sid,
        table.concat(_E.notifications):find('intentional listing failure', 1, true) ~= nil }
    end)(...)]], { method })
    eq(r, { true, { "kept" }, true, true })
  end
end

T["a superseded metadata response cannot replace the latest refresh"] = function()
  eq(child.lua_get([[(function()
    local n = _S.connect('memory')
    _E.exec(n._session_id, 'CREATE TABLE old_table (id INTEGER)')
    local request, held = _S.client.request, nil
    _S.client.request = function(method, params, callback)
      if method == 'dbridge/listTables' and not held then
        request(method, params, function(result, err)
          held = function() callback(result, err) end
        end)
      else request(method, params, callback) end
    end
    _S.explorer.handle_refresh()
    assert(_E.wait_for(function() return held ~= nil end))
    _E.exec(n._session_id, 'CREATE TABLE new_table (id INTEGER)')
    _S.refresh(n, 'new_table')
    held()
    _E.settle(50)
    return _S.tables(n)
  end)()]]), { "new_table", "old_table" })
end

T["deleting a Profile ignores its pending metadata response"] = function()
  eq(child.lua_get([[(function()
    local n = _S.connect('memory')
    local sid = n._session_id
    local request, held = _S.client.request, nil
    _S.client.request = function(method, params, callback)
      if method == 'dbridge/listTables' then
        request(method, params, function(result, err) held = function() callback(result, err) end end)
      else request(method, params, callback) end
    end
    _S.explorer.handle_refresh()
    assert(_E.wait_for(function() return held ~= nil end))
    _S.explorer.handle_delete()
    assert(_E.wait_for(function() return #_S.explorer.tree:get_nodes() == 0 end))
    held()
    _E.settle(50)
    local response = _E.request('dbridge/execute', { session_id = sid, sql = 'SELECT 1' })
    return { #_S.explorer.tree:get_nodes(), _S.explorer.get_active_session() == nil,
      _S.bar():find('No active Session', 1, true) ~= nil, response.err ~= false }
  end)()]]), { 0, true, true, true })
end

T["indicator and SQL operations share multi-Profile targets"] = function()
  child.lua([[
    _S.a = _S.connect('alpha')
    _S.b = _S.connect('beta')
    _E.exec_many(_S.a._session_id, { 'CREATE TABLE who (only_alpha TEXT)', "INSERT INTO who VALUES ('target_alpha')" })
    _E.exec_many(_S.b._session_id, { 'CREATE TABLE who (only_beta TEXT)', "INSERT INTO who VALUES ('target_beta')" })
    _S.focus(_S.a)
    _S.explorer.handle_enter()
    _S.edit()
    _S.editor.set_sql('SELECT * FROM who')
  ]])
  eq(child.lua_get("_S.bar():find('alpha (sqlite)', 1, true) ~= nil"), true)
  child.type_keys("\\r")
  eq(child.lua_get([[_E.wait_for(function()
    local p = require('dbridge.results').panel
    return table.concat(vim.api.nvim_buf_get_lines(p.bufnr, 0, -1, false)):find('target_alpha', 1, true) ~= nil
  end)]]), true)
  local completed = child.lua_get("_E.complete_at(...)", { { "SELECT w. FROM who w" }, 1, 9 })
  eq(completed.labels, { "only_alpha" })
  -- Merely moving the explorer cursor selects that target only while focused.
  child.lua("_S.focus(_S.b)")
  eq(child.lua_get("_S.bar():find('beta (sqlite)', 1, true) ~= nil"), true)
  child.lua("_S.edit()")
  eq(child.lua_get("_S.bar():find('alpha (sqlite)', 1, true) ~= nil"), true)
  -- Interacting with beta makes it persist when returning to the editor.
  child.lua("_S.focus(_S.b); _S.explorer.handle_enter(); _S.edit()")
  eq(child.lua_get("_S.bar():find(_S.b._session_id, 1, true) ~= nil"), true)
  completed = child.lua_get("_E.complete_at(...)", { { "SELECT w. FROM who w" }, 1, 9 })
  eq(completed.labels, { "only_beta" })
end

T["deleting the selected Profile shows the remaining target"] = function()
  eq(child.lua_get([[(function()
    local a = _S.connect('alpha')
    local b = _S.connect('beta')
    _S.explorer.handle_delete()
    assert(_E.wait_for(function() return #_S.explorer.tree:get_nodes() == 1 end))
    _S.edit()
    return { _S.explorer.get_active_session() == a._session_id,
      _S.bar():find('alpha (sqlite)', 1, true) ~= nil }
  end)()]]), { true, true })
end

T["failed connect and delete do not change the displayed target"] = function()
  eq(child.lua_get([[(function()
    local a = _S.connect('alpha')
    local b = _S.explorer.add_profile_node('bad', 'unknown-adapter', {})
    _S.focus(b)
    _S.explorer.handle_enter()
    assert(_E.wait_for(function() return #_E.notifications > 0 end))
    _S.edit()
    local before = _S.bar()
    local request = _S.client.request
    _S.client.request = function(method, params, callback)
      if method == 'dbridge/deleteProfile' then callback(nil, { message = 'delete denied' })
      else request(method, params, callback) end
    end
    _S.focus(a)
    _S.explorer.handle_delete()
    _S.edit()
    return { _S.explorer.get_active_session() == a._session_id,
      _S.bar() == before, #_S.explorer.tree:get_nodes() }
  end)()]]), { true, true, 2 })
end

T["no active target and special names are rendered literally"] = function()
  eq(child.lua_get("_S.bar():find('No active Session', 1, true) ~= nil"), true)
  eq(child.lua_get([[(function()
    local n = _S.connect('report%{1+1}')
    _S.edit()
    local rendered = vim.api.nvim_eval_statusline(_S.bar(), { winid = _S.editor.panel.winid, use_winbar = true, maxwidth = 500 }).str
    -- Editing configuration does not relabel the already bound Session adapter.
    n._adapter = 'duckdb'
    n._name = 'line\nbreak%{1+1}'
    _S.explorer.update_target()
    return { rendered:find('report%{1+1}', 1, true) ~= nil,
      _S.bar():find('(sqlite)', 1, true) ~= nil,
      _S.bar():find('line break', 1, true) ~= nil }
  end)()]]), { true, true, true })
end

T['stopped server clears the visible target'] = function()
  eq(child.lua_get([[(function()
    local n = _S.connect('alpha')
    _S.client.stop()
    return _E.wait_for(function()
      return _S.bar():find('No active Session', 1, true) ~= nil
        and _S.explorer.get_active_session() == nil and n._session_id == nil
        and #n:get_child_ids() == 0
    end)
  end)()]]), true)
end

T["pending refresh after UI teardown does not mutate the disposed tree"] = function()
  eq(child.lua_get([[(function()
    local n = _S.connect('memory')
    _E.exec(n._session_id, 'CREATE TABLE kept (value INTEGER)')
    local request, held = _S.client.request, nil
    _S.client.request = function(method, params, callback)
      if method == 'dbridge/listTables' then
        request(method, params, function(result, err) held = function() callback(result, err) end end)
      else request(method, params, callback) end
    end
    _S.explorer.handle_refresh()
    assert(_E.wait_for(function() return held ~= nil end))
    require('dbridge').close()
    local mutations = 0
    for _, method in ipairs({ 'add_node', 'remove_node', 'render' }) do
      _S.explorer.tree[method] = function() mutations = mutations + 1 end
    end
    held()
    _E.settle(50)
    return mutations
  end)()]]), 0)
end

T["pending connect after UI teardown releases its Session without rendering"] = function()
  eq(child.lua_get([[(function()
    local request, held, sid = _S.client.request, nil, nil
    _S.client.request = function(method, params, callback)
      if method == 'dbridge/connect' then
        request(method, params, function(result, err)
          sid = result.session_id
          held = function() callback(result, err) end
        end)
      else request(method, params, callback) end
    end
    local n = _S.explorer.add_profile_node('pending', 'sqlite', { uri = ':memory:' })
    _S.focus(n)
    _S.explorer.handle_enter()
    assert(_E.wait_for(function() return held ~= nil end))
    require('dbridge').close()
    local renders = 0
    _S.explorer.tree.render = function() renders = renders + 1 end
    held()
    local result = _E.request('dbridge/execute', { session_id = sid, sql = 'SELECT 1' })
    _E.settle(50)
    return { renders, n._session_id == nil, result.err ~= false }
  end)()]]), { 0, true, true })
end

return T
