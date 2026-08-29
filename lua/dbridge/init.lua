local Layout = require("nui.layout")
local client = require("dbridge.client")
local explorer = require("dbridge.explorer")
local editor = require("dbridge.editor")
local results = require("dbridge.results")

local M = {}
local _layout = nil
local _hidden = false

local _cfg = {
  -- Command to start the dbridge server. Defaults to the console script the
  -- server package installs; override for a venv/uv checkout, e.g.
  --   server_cmd = { "uv", "run", "python", "-m", "dbridge.server" }
  server_cmd = { "dbridge" },
}

local function execute_sql()
  local session_id = explorer.get_active_session()
  if not session_id then
    vim.notify("[dbridge] no active connection", vim.log.levels.WARN); return
  end
  local sql = editor.get_sql()
  if sql == "" then return end
  client.request("dbridge/execute", { session_id = session_id, sql = sql }, function(result, err)
    if err then
      vim.notify("[dbridge] execute error: " .. err.message, vim.log.levels.ERROR); return
    end
    vim.schedule(function() results.render(result) end)
  end)
end

local function init_layout()
  _layout = Layout(
    { position = "top", size = "100%", relative = "editor" },
    Layout.Box({
      Layout.Box(explorer.panel, { size = "20%" }),
      Layout.Box({
        Layout.Box(editor.panel,  { size = "60%" }),
        Layout.Box(results.panel, { size = "40%" }),
      }, { dir = "col", size = "80%" }),
    }, { dir = "row", size = "100%" })
  )
end

local function init_keymaps()
  local o = { noremap = true, nowait = true }
  -- explorer
  explorer.panel:map("n", "<CR>", function()
    local n = explorer.handle_enter()
    -- if a table node was returned, show a sample SELECT
    if n and n._type == "table" then
      local sid = explorer.get_active_session()
      if sid then
        local sql = "SELECT * FROM " .. n._fqn .. " LIMIT 100"
        editor.set_sql(sql)
        client.request("dbridge/execute", { session_id = sid, sql = sql }, function(r, e)
          if e then vim.notify("[dbridge] " .. e.message, vim.log.levels.ERROR); return end
          vim.schedule(function() results.render(r) end)
        end)
      end
    end
  end, o)
  explorer.panel:map("n", "a", explorer.handle_add_profile, o)
  explorer.panel:map("n", "e", explorer.handle_edit_profile, o)
  explorer.panel:map("n", "DD", explorer.handle_delete, o)
  explorer.panel:map("n", "R", explorer.handle_refresh, o)
  -- editor: run with <leader>r (normal + visual)
  editor.panel:map("n", "<leader>r", execute_sql, o)
  editor.panel:map("v", "<leader>r", execute_sql, o)
  -- results pagination
  results.panel:map("n", "n", results.next_page, o)
  results.panel:map("n", "p", results.prev_page, o)
end

function M.setup(opts)
  _cfg = vim.tbl_deep_extend("force", _cfg, opts or {})
end

local function open()
  if client.start(_cfg.server_cmd) == false then return end
  explorer.init()
  editor.init()
  results.init()
  init_layout()
  init_keymaps()

  -- re-init on close so :Dbridge works again
  local panels = { explorer.panel, editor.panel, results.panel }
  for _, p in ipairs(panels) do
    p:on("BufUnload", function()
      vim.schedule(function()
        local cur = vim.api.nvim_get_current_buf()
        for _, pp in ipairs(panels) do
          if pp.bufnr == cur then return end
        end
        _layout:unmount()
        vim.g.dbridge_loaded = 0
        _hidden = true
        open()
      end)
    end)
  end

  vim.cmd("tabnew")
  local tmp = vim.fn.bufnr()
  _layout:mount()
  vim.api.nvim_set_current_win(explorer.panel.winid)
  vim.g.dbridge_loaded = 1
  _hidden = false
  vim.api.nvim_buf_delete(tmp, { force = true })
end

vim.api.nvim_create_user_command("Dbridge", function()
  if vim.g.dbridge_loaded ~= 1 then
    open()
  elseif _hidden then
    _layout:show()
    vim.api.nvim_set_current_win(explorer.panel.winid)
    _hidden = false
  else
    _layout:hide()
    _hidden = true
  end
end, {})

return M
