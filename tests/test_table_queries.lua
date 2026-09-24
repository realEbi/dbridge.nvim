local H = require("tests.helpers")
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set()
local function quote(name) return '"' .. name:gsub('"', '""') .. '"' end

for _, adapter in ipairs({ "sqlite", "duckdb" }) do
  local database = adapter == "sqlite" and "main" or "memory"
  local A = MiniTest.new_set({ hooks = {
    pre_case = function()
      H.boot(child, { ui = true })
      child.lua("_Q = require('tests.table_queries_env')")
    end,
    post_case = function() H.shutdown(child) end,
  } })
  T[adapter] = A

  local function prepare(sqls)
    child.lua("_Q.seed_on_connect(...)", { sqls })
    child.lua("_Q.add_profile(...)", { adapter })
    child.type_keys("<CR>")
  end

  for _, name in ipairs({ "order items", "select", 'odd"name', "a.b", "it's a table" }) do
    A["Enter executes literal table name " .. name] = function()
      prepare({ "CREATE TABLE " .. quote(name) .. " (value TEXT)",
        "INSERT INTO " .. quote(name) .. " VALUES ('correct table')" })
      local sid = child.lua_get("_Q.focus_table(...)", { name, database, "main" })
      child.type_keys("<CR>")
      local identifier = (adapter == "sqlite" and '"main"' or '"memory"."main"') .. "." .. quote(name)
      local sql = "SELECT * FROM " .. identifier .. " LIMIT 100"
      local result = child.lua_get("_Q.query_result(...)", { sql, "correct table" })
      eq(result.ready, true)
      eq(result.sql, sql)
      eq(result.queries, { { session_id = sid, sql = sql } })
      eq(child.lua_get("_Q.selected._sql_identifier"), identifier)
    end
  end

  A["duplicate table names execute their selected namespace"] = function()
    local other = 'other."db'
    local sqls = {
      "CREATE TABLE products (value TEXT)", "INSERT INTO products VALUES ('wrong default')",
      "ATTACH ':memory:' AS " .. quote(other),
    }
    local scope, target
    if adapter == "sqlite" then
      scope = other
      target = quote(other) .. '."products"'
    else
      scope = 'order."schema'
      table.insert(sqls, "CREATE SCHEMA " .. quote(other) .. "." .. quote(scope))
      table.insert(sqls, "CREATE SCHEMA " .. quote(database) .. "." .. quote(scope))
      table.insert(sqls, "CREATE TABLE " .. quote(database) .. "." .. quote(scope) .. '.products (wrong_column TEXT)')
      target = quote(other) .. "." .. quote(scope) .. '."products"'
    end
    table.insert(sqls, "CREATE TABLE " .. target .. " (value TEXT)")
    table.insert(sqls, "INSERT INTO " .. target .. " VALUES ('selected namespace')")
    prepare(sqls)
    child.lua_get("_Q.focus_table(...)", { "products", other, scope })
    child.type_keys("<CR>")
    local result = child.lua_get("_Q.query_result(...)", { "SELECT * FROM " .. target .. " LIMIT 100", "selected namespace" })
    eq(result.ready, true)
  end

  A["metadata errors prevent execution and allow retry"] = function()
    prepare({ "CREATE TABLE products (value TEXT)", "INSERT INTO products VALUES ('retry worked')" })
    child.lua_get("_Q.focus_table(...)", { "products", database, "main" })
    child.lua("_Q.hold_metadata('error')")
    child.type_keys("<CR>")
    child.lua("_Q.release()")
    eq(child.lua_get("_E.wait_for(function() return #_E.notifications > 0 end)"), true)
    eq(child.lua_get("#_Q.queries"), 0)
    eq(child.lua_get("_Q.selected._loaded"), false)
    child.lua("_Q.restore()")
    child.type_keys("<CR>")
    local identifier = adapter == "sqlite" and '"main"."products"' or '"memory"."main"."products"'
    eq(child.lua_get("_Q.query_result(...).ready", { "SELECT * FROM " .. identifier .. " LIMIT 100", "retry worked" }), true)
  end

  A["missing identifier prevents generated execution"] = function()
    prepare({ "CREATE TABLE products (value TEXT)", "INSERT INTO products VALUES ('legacy works')" })
    child.lua_get("_Q.focus_table(...)", { "products", database, "main" })
    child.lua("_Q.hold_metadata('old')")
    child.type_keys("<CR>")
    child.lua("_Q.release()")
    eq(child.lua_get("_E.wait_for(function() return #_E.notifications > 0 end)"), true)
    eq(child.lua_get("#_Q.queries"), 0)
  end

  A["explicit null identifier prevents a bare-name fallback"] = function()
    prepare({ "CREATE TABLE products (value TEXT)" })
    child.lua_get("_Q.focus_table(...)", { "products", database, "main" })
    child.lua("_Q.hold_metadata('null')")
    child.type_keys("<CR>")
    child.lua("_Q.release()")
    eq(child.lua_get("_E.wait_for(function() return #_E.notifications > 0 end)"), true)
    eq(child.lua_get("#_Q.queries"), 0)
  end

  A["duplicate Enter and a changed active target keep one captured Session query"] = function()
    prepare({ "CREATE TABLE products (value TEXT)", "INSERT INTO products VALUES ('original session')" })
    local sid = child.lua_get("_Q.focus_table(...)", { "products", database, "main" })
    child.lua("_Q.hold_metadata('real')")
    child.type_keys("<CR>", "<CR>")
    eq(child.lua_get("_Q.held_calls"), 1)
    local alternate = child.lua_get("_E.connect_memory()")
    child.lua("_E.stub_active_session(...)", { alternate })
    child.lua("_Q.release()")
    local identifier = adapter == "sqlite" and '"main"."products"' or '"memory"."main"."products"'
    local result = child.lua_get("_Q.query_result(...)", { "SELECT * FROM " .. identifier .. " LIMIT 100", "original session" })
    eq(result.ready, true)
    eq(#result.queries, 1)
    eq(result.queries[1].session_id, sid)
  end

  A["late metadata after UI teardown cannot execute"] = function()
    prepare({ "CREATE TABLE products (value TEXT)" })
    child.lua_get("_Q.focus_table(...)", { "products", database, "main" })
    child.lua("_Q.hold_metadata('old')")
    child.type_keys("<CR>")
    child.lua("require('dbridge').close(); _Q.release()")
    child.lua("_E.settle()")
    eq(child.lua_get("#_Q.queries"), 0)
  end

  A["late metadata for a removed node cannot execute"] = function()
    prepare({ "CREATE TABLE products (value TEXT)" })
    child.lua_get("_Q.focus_table(...)", { "products", database, "main" })
    child.lua("_Q.hold_metadata('old')")
    child.type_keys("<CR>")
    child.lua("require('dbridge.explorer').tree:remove_node(_Q.selected:get_id()); _Q.release()")
    child.lua("_E.settle()")
    eq(child.lua_get("#_Q.queries"), 0)
  end
end
return T
