local H = require("tests.helpers")
local eq = MiniTest.expect.equality
local select_statement = require("dbridge.statements").at
local T = MiniTest.new_set()

local function cursor_input(marked)
  local start, finish = marked:find("<cursor>", 1, true)
  assert(start, "missing cursor marker")
  return marked:sub(1, start - 1) .. marked:sub(finish + 1), start - 1
end

local cases = {
  { "second statement", "SELECT 1; SELECT <cursor>2; SELECT 3;", "SELECT 2;" },
  { "terminator belongs to preceding SQL", "SELECT 1<cursor>; SELECT 2;", "SELECT 1;" },
  { "whitespace selects following SQL", "SELECT 1; <cursor> SELECT 2;", "SELECT 2;" },
  { "single quote escapes", "SELECT 0; SELECT 'it''s; <cursor>fine'; SELECT 2;", "SELECT 'it''s; fine';" },
  { "quoted identifier", 'SELECT 0; SELECT "a;""<cursor>b" FROM t; SELECT 2;', 'SELECT "a;""b" FROM t;' },
  { "backtick identifier", 'SELECT `<cursor>a;``b` FROM t; SELECT 2;', 'SELECT `a;``b` FROM t;' },
  { "SQLite bracket identifier", "SELECT [a;<cursor>b] FROM t; SELECT 2;", "SELECT [a;b] FROM t;", "sqlite" },
  { "DuckDB array with closing bracket in string", "SELECT ['a]<cursor>;b']; SELECT 2;", "SELECT ['a];b'];", "duckdb" },
  { "line comments", "SELECT 0; -- ignored;\nSELECT <cursor>1; SELECT 2;", "-- ignored;\nSELECT 1;" },
  { "nested DuckDB comments", "SELECT /* a; /* b; */ c; */ <cursor>1; SELECT 2;", "SELECT /* a; /* b; */ c; */ 1;", "duckdb" },
  { "SQLite comments end at first closer", "SELECT /* a; /* b; */ <cursor>1; SELECT 2;", "SELECT /* a; /* b; */ 1;", "sqlite" },
  { "dollar quotes", "SELECT $$a;<cursor>b$$; SELECT 2;", "SELECT $$a;b$$;", "duckdb" },
  { "tagged dollar quotes", "SELECT $body$a;$$<cursor>b$body$; SELECT 2;", "SELECT $body$a;$$b$body$;", "duckdb" },
  { "escaped DuckDB strings", "SELECT E'it\\'s; <cursor>fine'; SELECT 2;", "SELECT E'it\\'s; fine';", "duckdb" },
  { "Unicode multiline bytes", "SELECT 'é';\n-- 🌍\nSELECT '<cursor>café'; SELECT 2;", "-- 🌍\nSELECT 'café';" },
  { "final statement without terminator", "SELECT 1;\nSELECT <cursor>2", "SELECT 2" },
  { "cursor at EOF", "SELECT 1<cursor>", "SELECT 1" },
  { "earlier valid SQL before incomplete quote", "SELECT <cursor>1; SELECT 'unfinished", "SELECT 1;" },
  { "transaction begin is separate", "BEGIN; SELECT <cursor>1; COMMIT;", "SELECT 1;" },
  {
    "BEGIN names and END columns are not trigger control words",
    "CREATE TRIGGER begin INSERT ON begin BEGIN INSERT INTO log SELECT <cursor>end FROM begin; END; SELECT 9;",
    "CREATE TRIGGER begin INSERT ON begin BEGIN INSERT INTO log SELECT end FROM begin; END;",
    "sqlite",
  },
  {
    "EXPLAIN keeps the complete trigger definition",
    "EXPLAIN CREATE TRIGGER tr AFTER INSERT ON t BEGIN INSERT INTO log VALUES (1); <cursor>UPDATE log SET id = 2; END; SELECT 9;",
    "EXPLAIN CREATE TRIGGER tr AFTER INSERT ON t BEGIN INSERT INTO log VALUES (1); UPDATE log SET id = 2; END;",
    "sqlite",
  },
  {
    "EXPLAIN QUERY PLAN keeps a temporary trigger definition",
    "EXPLAIN QUERY PLAN CREATE TEMP TRIGGER tr AFTER INSERT ON t BEGIN INSERT INTO log VALUES (1); <cursor>UPDATE log SET id = 2; END; SELECT 9;",
    "EXPLAIN QUERY PLAN CREATE TEMP TRIGGER tr AFTER INSERT ON t BEGIN INSERT INTO log VALUES (1); UPDATE log SET id = 2; END;",
    "sqlite",
  },
  {
    "trigger body and CASE are one statement",
    "CREATE TEMP TRIGGER tr AFTER INSERT ON t BEGIN INSERT INTO log VALUES (CASE WHEN NEW.id = 1 THEN 2 ELSE 3 END); <cursor>UPDATE log SET id = id + 1; END; SELECT 9;",
    "CREATE TEMP TRIGGER tr AFTER INSERT ON t BEGIN INSERT INTO log VALUES (CASE WHEN NEW.id = 1 THEN 2 ELSE 3 END); UPDATE log SET id = id + 1; END;",
    "sqlite",
  },
}
T["selection"] = MiniTest.new_set()
for _, case in ipairs(cases) do
  T["selection"][case[1]] = function()
    local sql, offset = cursor_input(case[2])
    eq(select_statement(sql, offset, case[4]), case[3])
  end
end

T["invalid or empty input"] = MiniTest.new_set()
for _, marked in ipairs({
  "<cursor>", "  <cursor> ", "SELECT 1; <cursor>-- comment only;",
  "SELECT <cursor>'unfinished;", 'SELECT <cursor>"unfinished;',
  "SELECT <cursor>/* unfinished;", "SELECT <cursor>$$unfinished;",
  "CREATE TRIGGER tr AFTER INSERT ON t BEGIN <cursor>DELETE FROM t;",
}) do
  T["invalid or empty input"][marked] = function()
    local sql, offset = cursor_input(marked)
    local result, reason = select_statement(sql, offset)
    eq(result, nil)
    eq(type(reason), "string")
  end
end

for _, adapter in ipairs({ "sqlite", "duckdb" }) do
  local child = MiniTest.new_child_neovim()
  local A = MiniTest.new_set({ hooks = {
    pre_once = function()
      H.boot(child, { ui = true })
      local connected, err = H.request(child, "dbridge/connect", { adapter = adapter, config = { uri = ":memory:" } })
      eq(err, nil)
      child.lua([[
        local sid, adapter = ...
        _statement_sid = sid
        _E.stub_active_session(sid)
        require('dbridge.explorer').get_active_target = function()
          return { name = 'statements', adapter = adapter, session_id = sid }
        end
        local results = require('dbridge.results')
        local render = results.render
        results.render = function(result) _statement_result = result; render(result) end
        local client = require('dbridge.client')
        local request = client.request
        client.request = function(method, params, callback)
          if method == 'dbridge/execute' then _statement_request = params.sql end
          return request(method, params, callback)
        end
      ]], { connected.session_id, adapter })
    end,
    pre_case = function()
      child.type_keys("<Esc>")
      child.lua("_statement_result = false; _statement_request = false; _E.take_notifications()")
    end,
    post_once = function() H.shutdown(child) end,
  } })
  T[adapter] = A

  local function edit(marked)
    local sql, offset = cursor_input(marked)
    local prefix = sql:sub(1, offset)
    local _, newlines = prefix:gsub("\n", "")
    local col = #(prefix:match("[^\n]*$") or "")
    child.lua([[
      local sql, row, col = ...
      local editor = require('dbridge.editor')
      vim.api.nvim_set_current_win(editor.panel.winid)
      editor.set_sql(sql)
      vim.api.nvim_win_set_cursor(0, { row, col })
    ]], { sql, newlines + 1, col })
    return sql
  end

  local function result_rows()
    eq(child.lua_get("_E.wait_for(function() return _statement_result ~= false end)"), true)
    return child.lua_get("_statement_result.rows")
  end

  A["mapping executes only the chosen query and preserves the buffer"] = function()
    local sql = edit("SELECT 'wrong';\nSELECT '<cursor>café; 🌍' AS chosen;\nSELECT 'also wrong';")
    child.type_keys("\\s")
    eq(result_rows(), { { "café; 🌍" } })
    eq(child.lua_get([[table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]]), sql)
  end

  A["command executes one mutation"] = function()
    child.lua("_E.exec(_statement_sid, 'CREATE TABLE counters (id INTEGER)')")
    edit("INSERT INTO counters VALUES (1);\nINSERT INTO counters VALUES (<cursor>2);\nINSERT INTO counters VALUES (3);")
    child.lua("vim.cmd('DbridgeExecuteStatement')")
    result_rows()
    eq(child.lua_get("_E.exec(_statement_sid, 'SELECT id FROM counters').rows"), { { 2 } })
  end

  A["whole-buffer mapping retains its request"] = function()
    local sql = edit("SELECT <cursor>1; SELECT 2;")
    child.type_keys("\\r")
    eq(child.lua_get("_E.wait_for(function() return _statement_request ~= false end)"), true)
    eq(child.lua_get("_statement_request"), sql)
    child.lua_get("_E.settle()")
  end

  A["empty or incomplete statement sends no request"] = function()
    edit("-- <cursor>nothing to execute;")
    child.lua("vim.cmd('DbridgeExecuteStatement')")
    eq(child.lua_get("_statement_request"), false)
    eq(child.lua_get("#_E.take_notifications()"), 1)
    edit("SELECT '<cursor>unfinished;")
    child.lua("vim.cmd('DbridgeExecuteStatement')")
    eq(child.lua_get("_statement_request"), false)
    eq(child.lua_get("#_E.take_notifications()"), 1)
  end

  A["command outside editor sends no request"] = function()
    child.lua("vim.api.nvim_set_current_win(require('dbridge.results').panel.winid); vim.cmd('DbridgeExecuteStatement')")
    eq(child.lua_get("_statement_request"), false)
    eq(child.lua_get("#_E.take_notifications()"), 1)
  end

  if adapter == "sqlite" then
    for _, explain in ipairs({ "EXPLAIN", "EXPLAIN QUERY PLAN" }) do
      A[explain .. " trigger inspection cannot execute its body or neighboring SQL"] = function()
        local suffix = explain == "EXPLAIN" and "bytecode" or "plan"
        local source, audit, trigger = "source_" .. suffix, "audit_" .. suffix, "trigger_" .. suffix
        child.lua("_E.exec_many(_statement_sid, ...)", { {
          "CREATE TABLE " .. source .. " (id INTEGER)",
          "CREATE TABLE " .. audit .. " (id INTEGER)",
          "INSERT INTO " .. audit .. " VALUES (8)",
        } })
        local marked = explain .. " CREATE TEMP TRIGGER " .. trigger .. " AFTER INSERT ON " .. source
          .. " BEGIN INSERT INTO " .. audit .. " VALUES (1); <cursor>UPDATE " .. audit .. " SET id = 2; END;"
        local expected = marked:gsub("<cursor>", "")
        edit(marked .. " INSERT INTO " .. audit .. " VALUES (99);")
        child.lua("vim.cmd('DbridgeExecuteStatement')")
        result_rows()
        eq(child.lua_get("_statement_request"), expected)
        eq(child.lua_get("_E.exec(_statement_sid, ...).rows", { "SELECT * FROM " .. audit }), { { 8 } })
        eq(child.lua_get("_E.exec(_statement_sid, ...).rows", {
          "SELECT name FROM sqlite_temp_master WHERE type = 'trigger' AND name = '" .. trigger .. "'",
        }), {})
      end
    end

    A["trigger body executes as a complete definition"] = function()
      child.lua("_E.exec_many(_statement_sid, { 'CREATE TABLE begin (end INTEGER)', 'CREATE TABLE audit (id INTEGER)' })")
      edit("CREATE TRIGGER begin AFTER INSERT ON begin BEGIN\n INSERT INTO audit VALUES (NEW.end);\n <cursor>UPDATE audit SET id = id + 1;\nEND; INSERT INTO begin VALUES (99);")
      child.lua("vim.cmd('DbridgeExecuteStatement')")
      result_rows()
      eq(child.lua_get("_E.exec(_statement_sid, 'SELECT * FROM audit').rows"), {})
      child.lua("_E.exec(_statement_sid, 'INSERT INTO begin VALUES (4)')")
      eq(child.lua_get("_E.exec(_statement_sid, 'SELECT * FROM audit').rows"), { { 5 } })
    end
  else
    A["array string semicolons stay inside the selected query"] = function()
      edit("SELECT ['a]<cursor>;b'][1] AS value; SELECT 'wrong';")
      child.lua("vim.cmd('DbridgeExecuteStatement')")
      eq(result_rows(), { { "a];b" } })
    end
  end
end

return T
