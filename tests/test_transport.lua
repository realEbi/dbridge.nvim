-- Transport and protocol surface, driven against a real server subprocess.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()
local sid

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      H.boot(child)
      sid = child.lua_get("_E.connect_memory()")
    end,
    post_once = function() H.shutdown(child) end,
  },
})

T["framing"] = MiniTest.new_set()

T["framing"]["reassembles a response split across stdout chunks"] = function()
  child.lua("_E.exec(...)", { sid, "CREATE TABLE big (id INTEGER, payload TEXT)" })
  local inserts = {}
  for i = 1, 300 do
    table.insert(inserts, ("INSERT INTO big VALUES (%d, '%s')"):format(i, string.rep("x", 200)))
  end
  child.lua("_E.exec_many(...)", { sid, inserts })

  -- max_rows caps the reply at 100, but the frame is still far larger than one
  -- read: if chunk reassembly were wrong this would truncate or never resolve.
  local r = child.lua_get("_E.exec(...)", { sid, "SELECT * FROM big" })
  eq(r.row_count, 100)
  eq(#r.rows, 100)
  eq(r.columns, { "id", "payload" })
  eq(#r.rows[1][2], 200)
end

T["framing"]["reports truncation in warnings"] = function()
  local r = child.lua_get("_E.exec(...)", { sid, "SELECT * FROM big" })
  eq(r.warnings, { "result truncated to 100 rows" })
end

T["params"] = MiniTest.new_set()

-- Regression: vim.fn.json_encode({}) produces `[]`, which the server rejects
-- with -32600. This silently broke profile loading in the explorer.
T["params"]["a method taking no params succeeds"] = function()
  local r, err = H.request(child, "dbridge/listProfiles", vim.empty_dict())
  eq(err, nil)
  eq(type(r), "table")
end

T["introspection"] = MiniTest.new_set()

T["introspection"]["listTables and getTableSchema"] = function()
  child.lua("_E.exec(...)", { sid, "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)" })
  local tables = H.request(child, "dbridge/listTables", { session_id = sid, path = { "main" } })
  eq(vim.tbl_contains(vim.tbl_map(function(t) return t.name end, tables), "users"), true)

  local schema = H.request(child, "dbridge/getTableSchema", { session_id = sid, path = { "main" }, name = "users" })
  eq(vim.tbl_map(function(c) return c.name end, schema.columns), { "id", "name" })
  eq(schema.primary_key, { name = vim.NIL, columns = { "id" } })
  eq(schema.primary_keys, nil)
  eq(schema.columns[1].data_type, "INTEGER")
end

T["introspection"]["listDatabases declares SQLite namespaces"] = function()
  eq(H.request(child, "dbridge/listDatabases", { session_id = sid }), { { name = "main", internal = false } })
end

T["introspection"]["refreshSchema picks up a new table"] = function()
  H.request(child, "dbridge/listTables", { session_id = sid, path = { "main" } }) -- warm the cache
  child.lua("_E.exec(...)", { sid, "CREATE TABLE added_later (id INTEGER)" })
  eq(H.request(child, "dbridge/refreshSchema", { session_id = sid }).ok, true)
  local tables = H.request(child, "dbridge/listTables", { session_id = sid, path = { "main" } })
  eq(vim.tbl_contains(vim.tbl_map(function(t) return t.name end, tables), "added_later"), true)
end

T["introspection"]["getERD returns the placeholder without erroring"] = function()
  local r, err = H.request(child, "dbridge/getERD", { session_id = sid, path = { "main" } })
  eq(err, nil)
  eq(r.status, "not_implemented")
end

T["errors"] = MiniTest.new_set()

T["errors"]["unknown session is -32003"] = function()
  local r, err = H.request(child, "dbridge/execute", { session_id = "nope", sql = "SELECT 1" })
  eq(r, nil)
  eq(err.code, -32003)
end

T["errors"]["unknown profile is -32006"] = function()
  local r, err = H.request(child, "dbridge/connect", { profile = "does-not-exist" })
  eq(r, nil)
  eq(err.code, -32006)
end

T["errors"]["connect with neither profile nor adapter is -32600"] = function()
  local _, err = H.request(child, "dbridge/connect", { config = vim.empty_dict() })
  eq(err.code, -32600)
end

T["errors"]["a bad query surfaces -32002 without killing the session"] = function()
  local _, err = H.request(child, "dbridge/execute", { session_id = sid, sql = "SELECT * FROM nope" })
  eq(err.code, -32002)
  eq(child.lua_get("_E.exec(...)", { sid, "SELECT 1 AS one" }).rows, { { 1 } })
end

T["session"] = MiniTest.new_set()

T["session"]["disconnect invalidates the session"] = function()
  local other = child.lua_get("_E.connect_memory()")
  eq(H.request(child, "dbridge/disconnect", { session_id = other }).ok, true)
  local _, err = H.request(child, "dbridge/execute", { session_id = other, sql = "SELECT 1" })
  eq(err.code, -32003)
end

return T
