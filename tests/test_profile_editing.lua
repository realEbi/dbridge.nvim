-- Explorer edits against the real server with isolated saved Profiles.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local config_dir

local T = MiniTest.new_set({ hooks = {
  pre_case = function()
    config_dir = H.boot(child, { ui = true })
    child.lua([[
      _P = { explorer = require('dbridge.explorer'), editor = require('dbridge.editor') }
      local notify = vim.notify
      vim.notify = function(message, level)
        _P.notification = { message = message, level = level }
        notify(message, level)
      end
      function _P.focus(n)
        vim.api.nvim_set_current_win(_P.explorer.panel.winid)
        local _, row = _P.explorer.tree:get_node(n:get_id())
        vim.api.nvim_win_set_cursor(_P.explorer.panel.winid, { assert(row), 0 })
        vim.cmd('doautocmd CursorMoved')
      end
      function _P.add(name, adapter, config)
        assert(_E.profile_call('save', name, adapter, config).result)
        return _P.explorer.add_profile_node(name, adapter, config)
      end
      function _P.edit(n, name, adapter, config)
        _P.focus(n)
        local answers = { name, adapter, vim.json.encode(config) }
        local input = vim.ui.input
        vim.ui.input = function(_, callback) callback(table.remove(answers, 1)) end
        _P.notification = nil
        _E.take_notifications()
        _P.explorer.handle_edit_profile()
        vim.ui.input = input
        assert(_E.wait_for(function() return _P.notification ~= nil end))
      end
      function _P.snapshot()
        local out = {}
        for _, n in ipairs(_P.explorer.tree:get_nodes()) do
          out[n._name] = { adapter = n._adapter, config = n._config,
            session_id = n._session_id or false }
        end
        return out
      end
      function _P.bar()
        return vim.api.nvim_get_option_value('winbar', { win = _P.editor.panel.winid })
      end
    ]])
  end,
  post_case = function()
    H.shutdown(child)
    vim.fn.delete(config_dir, "rf")
  end,
} })

T["rename updates one node and survives a panel rebuild"] = function()
  eq(child.lua_get([[(function()
    local n = _P.add('old', 'sqlite', { uri = ':memory:' })
    local original_id = n:get_id()
    _P.edit(n, 'new', 'sqlite', { uri = ':memory:' })
    assert(n:get_id() == original_id and n._name == 'new')
    assert(#_P.explorer.tree:get_nodes() == 1)
    require('dbridge').close()
    vim.cmd('Dbridge')
    assert(_E.wait_for(function() return #_P.explorer.tree:get_nodes() == 1 end))
    return { _P.snapshot(), _E.profile_call('list').result }
  end)()]]), {
    { new = { adapter = "sqlite", config = { uri = ":memory:" }, session_id = false } },
    { new = { adapter = "sqlite", config = { uri = ":memory:" } } },
  })
end

T["same-name edit replaces configuration in place"] = function()
  eq(child.lua_get([[(function()
    local n = _P.add('same', 'sqlite', { uri = ':memory:' })
    local config = { uri = vim.env.XDG_CONFIG_HOME .. '/edited.sqlite' }
    _P.edit(n, 'same', 'sqlite', config)
    local listed = _E.profile_call('list').result
    return { #_P.explorer.tree:get_nodes(), n._name, n._adapter, vim.deep_equal(n._config, config),
      vim.tbl_count(listed), vim.deep_equal(listed.same, { adapter = 'sqlite', config = config }) }
  end)()]]), { 1, "same", "sqlite", true, 1, true })
end

T["collision reports the server error and retains both definitions and the Session"] = function()
  eq(child.lua_get([[(function()
    local n = _P.add('old', 'sqlite', { uri = ':memory:' })
    _P.add('taken', 'duckdb', { uri = ':memory:' })
    _P.focus(n)
    _P.explorer.handle_enter()
    assert(_E.wait_for(function() return n._session_id and #n:get_child_ids() > 0 end, 15000))
    local before = vim.deepcopy(_P.snapshot())
    local stored = _E.profile_call('list').result
    _P.edit(n, 'taken', 'duckdb', { uri = ':memory:' })
    return { vim.deep_equal(_P.snapshot(), before), vim.deep_equal(_E.profile_call('list').result, stored),
      _P.notification.message:find('already exists', 1, true) ~= nil,
      _P.notification.level == vim.log.levels.ERROR,
      _E.exec(n._session_id, 'SELECT 1').rows }
  end)()]]), { true, true, true, true, { { 1 } } })
end

T["missing source reports failure without adding a renamed node"] = function()
  eq(child.lua_get([[(function()
    local n = _P.add('removed', 'sqlite', { uri = ':memory:' })
    local before = vim.deepcopy(_P.snapshot())
    assert(_E.profile_call('delete', 'removed').result.ok)
    _P.edit(n, 'new', 'duckdb', { uri = ':memory:' })
    return { vim.deep_equal(_P.snapshot(), before), vim.tbl_count(_E.profile_call('list').result),
      _P.notification.message:find('removed', 1, true) ~= nil,
      _P.notification.level == vim.log.levels.ERROR }
  end)()]]), { true, 0, true, true })
end

T["node changes wait for successful confirmation"] = function()
  eq(child.lua_get([[(function()
    local n = _P.add('old', 'sqlite', { uri = ':memory:' })
    local before = vim.deepcopy(_P.snapshot())
    local client = require('dbridge.client')
    local request, held = client.request, nil
    client.request = function(method, params, callback)
      if method == 'dbridge/saveProfile' then
        return request(method, params, function(result, err)
          held = function() callback(result, err) end
        end)
      end
      return request(method, params, callback)
    end
    _P.focus(n)
    local answers = { 'new', 'duckdb', '{"uri":":memory:"}' }
    vim.ui.input = function(_, callback) callback(table.remove(answers, 1)) end
    _P.explorer.handle_edit_profile()
    assert(_E.wait_for(function() return held ~= nil end))
    local unchanged = vim.deep_equal(_P.snapshot(), before)
    held()
    return { unchanged, n._name, n._adapter, n._config }
  end)()]]), { true, "new", "duckdb", { uri = ":memory:" } })
end

for _, adapter in ipairs({ "sqlite", "duckdb" }) do
  T[adapter .. " connected rename keeps scope, indicator, and editor execution on its Session"] = function()
    child.lua([[
      local adapter = ...
      local config = { uri = ':memory:' }
      local n = _P.add('old', adapter, config)
      _P.focus(n)
      _P.explorer.handle_enter()
      assert(_E.wait_for(function() return n._session_id and #n:get_child_ids() > 0 end, 15000))
      _P.sid = n._session_id
      _E.exec_many(_P.sid, { 'CREATE TEMP TABLE retained (value INTEGER)', 'INSERT INTO retained VALUES (42)' })
      _E.exec(_P.sid, "ATTACH ':memory:' AS extra")
      _P.explorer.handle_refresh()
      local scope
      assert(_E.wait_for(function()
        for _, item in ipairs(_P.explorer.tree:get_nodes(n:get_id())) do
          if item._scope_path[1] == 'extra' then scope = item end
        end
        return scope ~= nil
      end, 15000))
      _P.focus(scope)
      _P.explorer.handle_enter()
      local active_path = vim.deepcopy(n._active_path)
      local opposite = adapter == 'sqlite' and 'duckdb' or 'sqlite'
      local replacement = { uri = vim.env.XDG_CONFIG_HOME .. '/replacement.db' }
      _P.edit(n, 'new', opposite, replacement)
      assert(n._session_id == _P.sid and vim.deep_equal(n._active_path, active_path))
      vim.api.nvim_set_current_win(_P.editor.panel.winid)
      vim.cmd('doautocmd WinEnter')
      assert(_E.wait_for(function() return _P.bar():find('new (' .. adapter .. ')', 1, true) ~= nil end))
      assert(_P.bar():find(_P.sid, 1, true))
      assert(vim.deep_equal(_P.explorer.get_query_target(_P.editor.panel.bufnr).path, active_path))
      assert(_E.exec(_P.sid, 'SELECT value FROM retained').rows[1][1] == 42)
      _P.editor.set_sql('SELECT 1')
      local client = require('dbridge.client')
      local request = client.request
      client.request = function(method, params, callback)
        if method == 'dbridge/execute' then
          _P.executed = vim.deepcopy(params)
          return request(method, params, function(result, err)
            _P.result, _P.error = result, err
            callback(result, err)
          end)
        end
        return request(method, params, callback)
      end
    ]], { adapter })
    child.type_keys("\\r")
    eq(child.lua_get([[(function()
      assert(_E.wait_for(function() return _P.result ~= nil or _P.error ~= nil end))
      return { _P.executed.session_id == _P.sid, _P.executed.sql, _P.result.rows, _P.error == nil }
    end)()]]), { true, "SELECT 1", { { 1 } }, true })
  end
end

return T
