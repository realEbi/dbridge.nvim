-- Cursor-aware SQL completion through the nvim-cmp source.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()
local sid
local KIND -- CompletionItemKind values, read from the child

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      H.boot(child, { ui = true })
      sid = child.lua_get("_E.connect_memory()")
      child.lua("_E.exec(...)", { sid, "CREATE TABLE users (id INTEGER, name TEXT, email TEXT)" })
      child.lua("_E.stub_active_session(...)", { sid })
      KIND = child.lua_get([[{
        class = tostring(vim.lsp.protocol.CompletionItemKind.Class),
        field = tostring(vim.lsp.protocol.CompletionItemKind.Field),
        keyword = tostring(vim.lsp.protocol.CompletionItemKind.Keyword),
      }]])
    end,
    post_once = function() H.shutdown(child) end,
  },
})

local function complete_at(lines, row, col)
  return child.lua_get("_E.complete_at(...)", { lines, row, col })
end

-- Regression: this returned zero items when the client sent only
-- cursor_before_line, because the FROM clause lives on the next line.
T["SELECT position on a multi-line statement returns columns"] = function()
  local r = complete_at({ "SELECT ", "FROM users" }, 1, 7)
  eq(r.labels, { "id", "name", "email" })
  eq(r.kinds[KIND.field], true)
end

T["SELECT position on a single line returns columns"] = function()
  local r = complete_at({ "SELECT  FROM users" }, 1, 7)
  eq(r.labels, { "id", "name", "email" })
  eq(r.kinds[KIND.field], true)
end

T["FROM position returns tables"] = function()
  local r = complete_at({ "SELECT * FROM " }, 1, 14)
  eq(vim.tbl_contains(r.labels, "users"), true)
  eq(r.kinds[KIND.class], true)
end

T["WHERE position returns columns"] = function()
  local r = complete_at({ "SELECT id FROM users WHERE " }, 1, 27)
  eq(r.labels, { "id", "name", "email" })
  eq(r.kinds[KIND.field], true)
end

T["WHERE position across lines returns columns"] = function()
  local r = complete_at({ "SELECT id", "FROM users", "WHERE " }, 3, 6)
  eq(r.labels, { "id", "name", "email" })
end

T["an empty buffer falls back to keywords"] = function()
  local r = complete_at({ "" }, 1, 0)
  eq(r.kinds[KIND.keyword], true)
  eq(vim.tbl_contains(r.labels, "SELECT"), true)
end

-- The offset is a UTF-8 byte offset on both sides; multi-byte text elsewhere in
-- the buffer must not shift what the cursor means.
T["offsets are byte-correct with multi-byte text in the buffer"] = function()
  local r = complete_at({ "SELECT ", "FROM users", "WHERE name = 'héllo'" }, 1, 7)
  eq(r.labels, { "id", "name", "email" })
end

T["carries insert_text and sort_key through"] = function()
  local r = complete_at({ "SELECT * FROM " }, 1, 14)
  eq(r.first.insertText, '"main"."users"')
  eq(type(r.first.sortText), "string")
  eq(r.first.textEdit, nil)
end

T["cmp_format renders dbridge kinds, not LSP ones"] = function()
  local table_item = child.lua_get("_E.format_at(...)", { { "SELECT * FROM " }, 1, 14 })
  eq(table_item.kind, " table")
  eq(table_item.menu, "[DBRIDGE]")

  local column_item = child.lua_get("_E.format_at(...)", { { "SELECT ", "FROM users" }, 1, 7 })
  eq(column_item.kind, " column")

  local keyword_item = child.lua_get("_E.format_at(...)", { { "" }, 1, 0 })
  eq(keyword_item.kind, "󰌋 keyword")
end

T["cmp_format leaves an entry without a dbridge kind alone"] = function()
  local item = child.lua_get("_E.format_foreign()")
  eq(item.kind, "Text")
  eq(item.menu, "[DBRIDGE]")
end

T["returns nothing when there is no active session"] = function()
  child.lua("_E.stub_active_session(nil)")
  local r = complete_at({ "SELECT * FROM " }, 1, 14)
  eq(r.labels, {})
  child.lua("_E.stub_active_session(...)", { sid })
end

return T
