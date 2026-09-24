-- Shared scope migration: real server, real explorer, and executable completion.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set()

for _, adapter in ipairs({ "sqlite", "duckdb" }) do
  local first = adapter == "sqlite" and "main" or "memory"
  local attached = "other.catalog"
  local A = MiniTest.new_set({ hooks = {
    pre_case = function()
      H.boot(child, { ui = true })
      child.lua([[
        _Q = require('tests.table_queries_env')
        _B = { explorer = require('dbridge.explorer'), editor = require('dbridge.editor') }
        function _B.focus_table(database)
          _Q.focus_table('products', database, 'main')
          _B.explorer.update_target()
          vim.api.nvim_set_current_win(_B.editor.panel.winid)
          return _B.explorer.get_query_target(_B.editor.panel.bufnr)
        end
        function _B.refresh(from_selection)
          local root = _B.explorer.tree:get_nodes()[1]
          if not from_selection then _Q.focus(root) end
          local previous = _B.explorer.tree:get_node(root:get_child_ids()[1])
          _B.explorer.handle_refresh()
          assert(_E.wait_for(function() return _B.explorer.tree:get_node(root:get_child_ids()[1]) ~= previous end))
          return root
        end
      ]])
      local target = adapter == "sqlite" and '"other.catalog"' or '"other.catalog"."main"'
      child.lua("_Q.seed_on_connect(...)", { {
        "CREATE TABLE products (value TEXT)", "INSERT INTO products VALUES ('default value')",
        "ATTACH ':memory:' AS \"other.catalog\"",
        "CREATE TABLE " .. target .. ".products (value TEXT)",
        "INSERT INTO " .. target .. ".products VALUES ('attached value')",
        "CREATE TABLE " .. target .. ".shipments (tracking TEXT)",
      } })
      child.lua("_Q.add_profile(...)", { adapter })
      child.type_keys("<CR>")
      child.lua_get("_Q.focus_table(...)", { "products", first, "main" })
    end,
    post_case = function() H.shutdown(child) end,
  } })
  T[adapter] = A

  A["declared tiers retain literal paths and internal markers"] = function()
    local got = child.lua_get([[(function()
      local tree = _B.explorer.tree
      local root = tree:get_nodes()[1]
      local found = {}
      local function visit(n, path)
        if n._type == 'table' and n._table == 'products' then
          found[#found + 1] = { path = n._scope_path, depth = n:get_depth() - root:get_depth() - 1 }
        end
        for _, item in ipairs(tree:get_nodes(n:get_id())) do visit(item) end
      end
      visit(root)
      local internal = false
      for _, n in ipairs(tree:get_nodes(root:get_id())) do
        assert(n._type == 'scope')
        assert(type(n._internal) == 'boolean')
        if n._internal then internal = true end
      end
      return { found = found, levels = root._levels, dialect = root._session_dialect, internal = internal }
    end)()]] )
    local expected = adapter == "sqlite" and 1 or 2
    eq(#got.levels, expected)
    eq(got.dialect, adapter)
    eq(#got.found, 2)
    for _, entry in ipairs(got.found) do
      eq(entry.depth, expected)
      eq(#entry.path, expected)
    end
    eq(got.internal, adapter == "duckdb")
  end

  A["complete each scope and execute its insertion unchanged"] = function()
    for _, catalog in ipairs({ first, attached }) do
      local target = child.lua_get("_B.focus_table(...)", { catalog })
      local complete = child.lua_get("_E.complete_at(...)", { { "SELECT * FROM " }, 1, 14 })
      eq(complete.labels, catalog == first and { "products" } or { "products", "shipments" })
      local insertion = complete.first.insertText
      eq(complete.first.label, "products")
      local result = child.lua_get("_E.exec(...)", { target.session_id, "SELECT * FROM " .. insertion })
      eq(result.rows, { { catalog == first and "default value" or "attached value" } })
    end
  end

  A["actual cmp acceptance inserts the attached identifier"] = function()
    local target = child.lua_get("_B.focus_table(...)", { attached })
    child.lua([[
      local cmp = require('cmp')
      cmp.setup({ sources = { { name = 'dbridge' } }, preselect = cmp.PreselectMode.None,
        mapping = { ['<CR>'] = cmp.mapping.confirm({ select = true }) },
        snippet = { expand = function() end } })
      _B.editor.set_sql('SELECT * FROM ')
      vim.api.nvim_win_set_cursor(_B.editor.panel.winid, { 1, 13 })
    ]])
    child.type_keys("A")
    child.lua("require('cmp').complete()")
    eq(child.lua_get([[_E.wait_for(function()
      local cmp = require('cmp')
      return cmp.visible() and #cmp.get_entries() == 2
    end)]]), true)
    child.type_keys("<CR>")
    local sql = child.lua_get([[(function()
      assert(_E.wait_for(function() return not require('cmp').visible() end))
      return table.concat(vim.api.nvim_buf_get_lines(_B.editor.panel.bufnr, 0, -1, false), '\n')
    end)()]] )
    local identifier = adapter == "sqlite" and '"other.catalog"."products"' or '"other.catalog"."main"."products"'
    eq(sql, "SELECT * FROM " .. identifier)
    eq(child.lua_get("_E.exec(...).rows", { target.session_id, sql }), { { "attached value" } })
  end

  A["SQL buffers retain independent scopes"] = function()
    child.lua_get("_B.focus_table(...)", { first })
    child.lua([[
      _B.extra = vim.api.nvim_create_buf(true, false)
      _B.initial = _B.explorer.get_query_target(_B.extra)
    ]])
    local selected = child.lua_get("_B.focus_table(...)", { attached })
    local original = child.lua_get("_B.explorer.get_query_target(_B.extra)")
    eq(original.path[1], first)
    eq(selected.path[1], attached)
  end

  A["refresh from an attached table preserves focus and resets a removed scope"] = function()
    local sid = child.lua_get("_Q.focus_table(...)", { "products", attached, "main" })
    local focused = child.lua_get([[(function()
      _B.explorer.update_target()
      _B.refresh(true)
      vim.cmd('doautocmd CursorMoved')
      _E.settle(50)
      local selected = _B.explorer.tree:get_node()
      return {
        kind = selected._type, path = selected._scope_path,
        target = _B.explorer.get_query_target(_B.editor.panel.bufnr).path,
      }
    end)()]])
    local path = adapter == "sqlite" and { attached } or { attached, "main" }
    eq(focused, { kind = "table", path = path, target = path })
    local completed = child.lua_get("_E.complete_at(...)", { { "SELECT * FROM " }, 1, 14 })
    eq(child.lua_get("_E.exec(...).rows", { sid, "SELECT * FROM " .. completed.first.insertText }),
      { { "attached value" } })

    -- Start the next refresh on the soon-to-be-removed table, exercising the
    -- normal R mapping position instead of masking it by focusing the Profile.
    child.lua_get("_Q.focus_table(...)", { "products", attached, "main" })
    child.lua("_E.exec(...)", { sid, 'DETACH "other.catalog"' })
    local reset = child.lua_get([[(function()
      _B.refresh(true)
      vim.cmd('doautocmd CursorMoved')
      _E.settle(50)
      return {
        kind = _B.explorer.tree:get_node()._type,
        path = _B.explorer.get_query_target(_B.editor.panel.bufnr).path,
      }
    end)()]])
    eq(reset, { kind = "connection", path = adapter == "sqlite" and { "main" } or { "memory", "main" } })
    completed = child.lua_get("_E.complete_at(...)", { { "SELECT * FROM " }, 1, 14 })
    eq(child.lua_get("_E.exec(...).rows", { sid, "SELECT * FROM " .. completed.first.insertText }),
      { { "default value" } })
  end

  A["refresh sees attachments retains selection and resets detached scope"] = function()
    local selected = child.lua_get("_B.focus_table(...)", { attached })
    child.lua("_E.exec(...)", { selected.session_id, "ATTACH ':memory:' AS later" })
    local retained = child.lua_get([[(function()
      local root = _B.refresh()
      local found = false
      for _, n in ipairs(_B.explorer.tree:get_nodes(root:get_id())) do
        if n._scope_path[1] == 'later' then found = true end
      end
      return { found, root._active_path[1], root._session_id }
    end)()]] )
    eq(retained, { true, attached, selected.session_id })
    child.lua("_E.exec(...)", { selected.session_id, 'DETACH "other.catalog"' })
    eq(child.lua_get([[(function()
      local root = _B.refresh()
      return _B.explorer.get_query_target(_B.editor.panel.bufnr).path
    end)()]]), adapter == "sqlite" and { "main" } or { "memory", "main" })
  end
end
return T
