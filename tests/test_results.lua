-- Results panel rendering. Needs the UI mounted: the panel writes to a window.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()
local sid

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      H.boot(child, { ui = true })
      sid = child.lua_get("_E.connect_memory()")
      -- deliberately non-alphabetical: the old code derived columns from
      -- pairs() over a hash table, whose iteration order is unspecified
      child.lua("_E.exec(...)", { sid, "CREATE TABLE t (zebra INTEGER, apple TEXT, mango REAL)" })
      local inserts = {}
      for i = 1, 150 do
        table.insert(inserts, ("INSERT INTO t VALUES (%d, 'a%d', %d.5)"):format(i, i, i))
      end
      child.lua("_E.exec_many(...)", { sid, inserts })
    end,
    post_once = function() H.shutdown(child) end,
  },
})

T["renders columns in the server's order"] = function()
  local r = child.lua_get("_E.render(...)", { sid, "SELECT * FROM t" })
  eq(r.columns, { "zebra", "apple", "mango" })
  -- line 1 is the box border; line 2 is the header row
  eq(r.lines[2], "│zebra│apple│mango│")
end

T["surfaces the truncation warning"] = function()
  local r = child.lua_get("_E.render(...)", { sid, "SELECT * FROM t" })
  eq(r.warnings, { "result truncated to 100 rows" })
  eq(vim.tbl_contains(r.notifications, "[dbridge] result truncated to 100 rows"), true)
  eq(r.statusline:find("truncated", 1, true) ~= nil, true)
end

T["paginates within the fetched rows"] = function()
  local r = child.lua_get("_E.render(...)", { sid, "SELECT * FROM t" })
  eq(r.statusline:find("page 1/5", 1, true) ~= nil, true)
  eq(child.lua_get("_E.results_page(...)", { "next" }):find("page 2/5", 1, true) ~= nil, true)
  eq(child.lua_get("_E.results_page(...)", { "prev" }):find("page 1/5", 1, true) ~= nil, true)
end

T["renders an empty result"] = function()
  local r = child.lua_get("_E.render(...)", { sid, "SELECT * FROM t WHERE zebra < 0" })
  eq(r.lines[1], "(no results)")
end

--- Split a rendered NuiTable row into trimmed cell values.
local function cells(line)
  local out = {}
  for cell in line:gmatch("[^│]+") do
    table.insert(out, (cell:gsub("^%s+", ""):gsub("%s+$", "")))
  end
  return out
end

T["distinguishes NULL from the empty string"] = function()
  child.lua("_E.exec_many(...)", { sid, {
    "CREATE TABLE n (a TEXT, b TEXT)",
    "INSERT INTO n VALUES (NULL, '')",
  } })
  local r = child.lua_get("_E.render(...)", { sid, "SELECT a, b FROM n" })
  -- NULL is spelled out; the empty string renders as an empty cell. Column
  -- widths are content-driven, so compare cells rather than the raw line.
  eq(cells(r.lines[2]), { "a", "b" })
  eq(cells(r.lines[4]), { "NULL", "" })
end

T["keeps duplicate column names as separate columns"] = function()
  local r = child.lua_get("_E.render(...)", { sid, "SELECT NULL AS x, 1 AS x FROM t LIMIT 1" })
  eq(r.columns, { "x", "x" })
  eq(cells(r.lines[2]), { "x", "x" })
end

return T
