-- Helpers run inside the child; all requests still use the real server.
local E = {}
local client = require("dbridge.client")
local explorer = require("dbridge.explorer")
local original_request = client.request

function E.seed_on_connect(sqls)
  E.queries, E.metadata_calls = {}, 0
  client.request = function(method, params, callback)
    if method == "dbridge/execute" then table.insert(E.queries, params) end
    if method == "dbridge/getTableSchema" then E.metadata_calls = E.metadata_calls + 1 end
    if method ~= "dbridge/connect" then return original_request(method, params, callback) end
    return original_request(method, params, function(result, err)
      if err then callback(result, err); return end
      local index = 0
      local function next_sql()
        index = index + 1
        if not sqls[index] then callback(result, nil); return end
        original_request("dbridge/execute", { session_id = result.session_id, sql = sqls[index] }, function(_, failure)
          assert(not failure, vim.inspect(failure))
          next_sql()
        end)
      end
      next_sql()
    end)
  end
end

local function walk(nodes, found)
  found = found or {}
  for _, n in ipairs(nodes) do
    table.insert(found, n)
    walk(explorer.tree:get_nodes(n:get_id()), found)
  end
  return found
end

function E.find_table(name, database, schema)
  for _, n in ipairs(walk(explorer.tree:get_nodes())) do
    if n._type == "table" and n._table == name
      and n._table_ref.database == database and n._table_ref.schema == schema then return n end
  end
end

function E.focus(n)
  local ancestor = n
  while ancestor:get_parent_id() do
    ancestor = explorer.tree:get_node(ancestor:get_parent_id())
    ancestor:expand()
  end
  explorer.tree:render()
  local _, row = explorer.tree:get_node(n:get_id())
  vim.api.nvim_set_current_win(explorer.panel.winid)
  vim.api.nvim_win_set_cursor(explorer.panel.winid, { row, 0 })
end

function E.add_profile(adapter)
  local n = explorer.add_profile_node("identifier_test", adapter, { uri = ":memory:" })
  E.focus(n)
  return true
end

function E.focus_table(name, database, schema)
  local n
  assert(vim.wait(10000, function()
    n = E.find_table(name, database, schema)
    return n ~= nil
  end, 10), "table missing from explorer")
  E.focus(n)
  E.selected = n
  return n._session_id
end

function E.query_result(expected_sql, expected_value)
  local results = require("dbridge.results")
  local lines = {}
  local ready = vim.wait(10000, function()
    lines = vim.api.nvim_buf_get_lines(results.panel.bufnr, 0, -1, false)
    return #E.queries > 0 and E.queries[#E.queries].sql == expected_sql
      and table.concat(lines, "\n"):find(expected_value, 1, true) ~= nil
  end, 10)
  return {
    ready = ready, queries = E.queries,
    sql = table.concat(vim.api.nvim_buf_get_lines(require("dbridge.editor").panel.bufnr, 0, -1, false), "\n"),
  }
end

function E.hold_metadata(mode)
  local request = client.request
  client.request = function(method, params, callback)
    if method ~= "dbridge/getTableSchema" then return request(method, params, callback) end
    E.held_calls = (E.held_calls or 0) + 1
    E.release = function()
      if mode == "error" then callback(nil, { message = "metadata failed" })
      elseif mode == "null" then callback({ columns = {}, sql_identifier = vim.NIL }, nil)
      elseif mode == "old" then callback({ columns = {} }, nil)
      else request(method, params, callback) end
    end
  end
  E.restore = function() client.request = request end
end

return E
