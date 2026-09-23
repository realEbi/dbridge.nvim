-- Exercise the actual nvim-cmp popup and confirmation, not source:complete().
local H = require("tests.helpers")
local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set()

local function edit(lines, row, col)
  child.lua([[
    local lines, row, col = ...
    local editor = require("dbridge.editor")
    vim.api.nvim_set_current_win(editor.panel.winid)
    vim.api.nvim_buf_set_lines(editor.panel.bufnr, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(editor.panel.winid, { row, col })
  ]], { lines, row, col })
  child.type_keys("i")
end

-- Wait in the child so mini.test's parent scheduler remains free.
local function visible_labels(expected)
  local result = child.lua_get([[(function(expected)
    local cmp = require("cmp")
    local labels = {}
    local ready = vim.wait(5000, function()
      labels = {}
      for _, entry in ipairs(cmp.get_entries()) do
        table.insert(labels, entry:get_completion_item().label)
      end
      table.sort(labels)
      return cmp.visible() and vim.deep_equal(labels, expected)
    end, 10)
    return { ready = ready, labels = labels }
  end)(...)]], { expected })
  eq(result, { ready = true, labels = expected })
end

local function accept(expected)
  child.type_keys("<CR>")
  local result = child.lua_get([[(function(expected)
    local ready = vim.wait(3000, function()
      return not require("cmp").visible()
        and vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), expected)
    end, 10)
    return { ready = ready, lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
  end)(...)]], { expected })
  eq(result, { ready = true, lines = expected })
end

for _, adapter in ipairs({ "sqlite", "duckdb" }) do
  local A = MiniTest.new_set({ hooks = {
    pre_once = function()
      H.boot(child, { ui = true })
      local connection, err = H.request(child, "dbridge/connect", {
        adapter = adapter, config = { uri = ":memory:" },
      }, 30000)
      eq(err, nil)
      local sid = connection.session_id
      child.lua("_E.exec(...)", {
        sid,
        "CREATE TABLE products (id INTEGER, sku TEXT, name TEXT, category TEXT, price REAL, discontinued BOOLEAN)",
      })
      child.lua("_E.exec(...)", { sid, 'CREATE TABLE localized ("café" TEXT, "κόσμος" TEXT)' })
      child.lua("_E.stub_active_session(...)", { sid })
      child.lua([[
        local cmp = require("cmp")
        cmp.setup({
          sources = { { name = "dbridge" } },
          preselect = cmp.PreselectMode.None,
          performance = { debounce = 0, throttle = 0 },
          mapping = { ["<CR>"] = cmp.mapping.confirm({ select = true }) },
          snippet = { expand = function() end },
        })
      ]])
    end,
    post_once = function() H.shutdown(child) end,
    pre_case = function()
      child.type_keys("<Esc>")
      child.lua("require('cmp').abort()")
    end,
  } })
  T[adapter] = A

  local all_columns = { "category", "discontinued", "id", "name", "price", "sku" }

  A["typing dot automatically opens columns at the first SELECT item"] = function()
    local prefix = "SELECT "
    edit({ prefix .. ", p.category FROM products p LIMIT 100" }, 1, #prefix)
    child.type_keys("p")
    child.type_keys(".")
    visible_labels(all_columns)
    child.type_keys("na")
    visible_labels({ "name" })
    accept({ "SELECT p.name, p.category FROM products p LIMIT 100" })
  end

  A["typing dot automatically opens columns after a comma"] = function()
    local prefix = "SELECT p.name, "
    edit({ prefix .. " FROM products p LIMIT 100" }, 1, #prefix)
    child.type_keys("p")
    child.type_keys(".")
    visible_labels(all_columns)
    child.type_keys("ca")
    visible_labels({ "category" })
    accept({ "SELECT p.name, p.category FROM products p LIMIT 100" })
  end

  A["manual completion replaces the identifier suffix with default Insert confirmation"] = function()
    edit({ "SELECT p.name, p.category FROM products p LIMIT 100" }, 1, #"SELECT p.na")
    child.lua("require('cmp').complete()")
    visible_labels({ "name" })
    accept({ "SELECT p.name, p.category FROM products p LIMIT 100" })
  end

  A["qualified replacement spans whitespace after the dot on a prior line"] = function()
    local lines = { "SELECT p.", "name FROM products p LIMIT 100" }
    edit(lines, 2, #"na")
    child.lua("require('cmp').complete()")
    visible_labels({ "name" })
    accept(lines)
  end

  A["automatic dot completion replaces an existing identifier"] = function()
    edit({ "SELECT name FROM products p LIMIT 100" }, 1, #"SELECT ")
    child.type_keys("p")
    child.type_keys(".")
    visible_labels(all_columns)
    child.type_keys("ca")
    visible_labels({ "category" })
    accept({ "SELECT p.category FROM products p LIMIT 100" })
  end

  A["UTF-8 bytes before the cursor preserve the surrounding query"] = function()
    local prefix = "SELECT 'héllo 🌍', "
    edit({ "-- café 🌍", prefix .. "name", "FROM products p LIMIT 100" }, 2, #prefix)
    child.type_keys("p")
    child.type_keys(".")
    visible_labels(all_columns)
    child.type_keys("ca")
    visible_labels({ "category" })
    accept({ "-- café 🌍", "SELECT 'héllo 🌍', p.category", "FROM products p LIMIT 100" })
  end

  A["unqualified columns after a comma can be filtered and accepted"] = function()
    local prefix = "SELECT id, "
    edit({ prefix .. " FROM products" }, 1, #prefix)
    child.lua("require('cmp').complete()")
    visible_labels(all_columns)
    child.type_keys("ca")
    visible_labels({ "category" })
    accept({ "SELECT id, category FROM products" })
  end

  A["typing an unqualified prefix requests matching columns"] = function()
    local prefix = "SELECT id, "
    edit({ prefix .. " FROM products" }, 1, #prefix)
    child.type_keys("n")
    child.type_keys("a")
    visible_labels({ "name" })
    accept({ "SELECT id, name FROM products" })
  end

  A["unqualified Unicode replacement preserves other lines and multibyte text"] = function()
    local prefix = "SELECT '🌍', ca"
    edit({ "-- café", prefix .. "fé", "FROM localized" }, 2, #prefix)
    child.lua("require('cmp').complete()")
    visible_labels({ "café" })
    accept({ "-- café", "SELECT '🌍', café", "FROM localized" })
  end

  A["bare SELECT displays the server keyword fallback"] = function()
    edit({ "SELECT " }, 1, #"SELECT ")
    -- At end of a line normal-mode cursors stop before the final space.
    child.type_keys("<End>")
    child.lua("require('cmp').complete()")
    local result = child.lua_get([[(function()
      local cmp = require("cmp")
      local ready = vim.wait(5000, function()
        local found_from = false
        for _, entry in ipairs(cmp.get_entries()) do
          local item = entry:get_completion_item()
          if item.kind ~= vim.lsp.protocol.CompletionItemKind.Keyword then return false end
          if item.textEdit ~= nil then return false end
          if item.label == "FROM" then found_from = true end
        end
        return cmp.visible() and found_from
      end, 10)
      return ready
    end)()]])
    eq(result, true)
  end

  A["unqualified midword completion replaces the whole identifier"] = function()
    edit({ "SELECT id, name FROM products" }, 1, #"SELECT id, na")
    child.lua("require('cmp').complete()")
    visible_labels({ "name" })
    accept({ "SELECT id, name FROM products" })
  end

  A["midword completion replaces a Unicode identifier suffix"] = function()
    local prefix = "SELECT '🌍', p.ca"
    edit({ prefix .. "fé FROM localized p" }, 1, #prefix)
    child.lua("require('cmp').complete()")
    visible_labels({ "café" })
    accept({ "SELECT '🌍', p.café FROM localized p" })
  end
end

return T
