local Layout = require("nui.layout")
local client = require("dbridge.client")
local explorer = require("dbridge.explorer")
local editor = require("dbridge.editor")
local results = require("dbridge.results")

local M = {}

local _layout = nil
local _hidden = false
-- Guards the teardown path. Unmounting the layout unloads the panel buffers,
-- which fires their own BufUnload handlers; without this they would re-enter
-- teardown (and, previously, open()) and never terminate.
local _tearing_down = false

local _cfg = {
  -- Command to start the dbridge server. Defaults to the console script the
  -- server package installs; override for a venv/uv checkout, e.g.
  --   server_cmd = { "uv", "run", "python", "-m", "dbridge.server" }
  server_cmd = { "dbridge" },
}

local function run_sql(sql, session_id)
  session_id = session_id or explorer.get_active_session()
  if not session_id then
    vim.notify("[dbridge] no active connection", vim.log.levels.WARN)
    return
  end
  if not sql or sql == "" then return end
  client.request("dbridge/execute", { session_id = session_id, sql = sql }, function(result, err)
    vim.schedule(function()
      if err then
        vim.notify("[dbridge] execute error: " .. err.message, vim.log.levels.ERROR)
        return
      end
      results.render(result)
    end)
  end)
end

local function execute_sql()
  run_sql(editor.get_sql())
end

local function init_layout()
  _layout = Layout(
    { position = "top", size = "100%", relative = "editor" },
    Layout.Box({
      Layout.Box(explorer.panel, { size = "20%" }),
      Layout.Box({
        Layout.Box(editor.panel, { size = "60%" }),
        Layout.Box(results.panel, { size = "40%" }),
      }, { dir = "col", size = "80%" }),
    }, { dir = "row", size = "100%" })
  )
end

local function init_keymaps()
  local o = { noremap = true, nowait = true }
  explorer.panel:map("n", "<CR>", function()
    explorer.handle_enter(function(n)
      local sql = "SELECT * FROM " .. n._sql_identifier .. " LIMIT 100"
      editor.set_sql(sql)
      run_sql(sql, n._session_id)
    end)
  end, o)
  explorer.panel:map("n", "a", explorer.handle_add_profile, o)
  explorer.panel:map("n", "e", explorer.handle_edit_profile, o)
  explorer.panel:map("n", "DD", explorer.handle_delete, o)
  explorer.panel:map("n", "R", explorer.handle_refresh, o)
  editor.panel:map("n", "<leader>r", execute_sql, o)
  editor.panel:map("v", "<leader>r", execute_sql, o)
  results.panel:map("n", "n", results.next_page, o)
  results.panel:map("n", "p", results.prev_page, o)
end

--- Tear the UI down exactly once. Safe to call from a BufUnload handler.
local function teardown()
  if _tearing_down then return end
  _tearing_down = true
  if _layout then
    pcall(function() _layout:unmount() end)
  end
  _layout = nil
  _hidden = false
  vim.g.dbridge_loaded = 0
  _tearing_down = false
end

local function open()
  if client.start(_cfg.server_cmd) == false then return end

  explorer.init()
  editor.init()
  explorer.on_active_changed = editor.update_target
  client.on_state_changed = explorer.server_state_changed
  local target_group = vim.api.nvim_create_augroup("DbridgeActiveTarget", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "WinEnter", "BufEnter" }, {
    group = target_group,
    callback = function() explorer.update_target() end,
  })
  results.init()
  init_layout()
  init_keymaps()

  -- Closing any panel tears the whole UI down. It does NOT rebuild it: the
  -- :Dbridge command already constructs a fresh layout on demand, and
  -- rebuilding here is what caused the unload/rebuild loop.
  for _, p in ipairs({ explorer.panel, editor.panel, results.panel }) do
    p:on("BufUnload", function()
      if _tearing_down then return end
      vim.schedule(teardown)
    end)
  end

  vim.cmd("tabnew")
  local tmp = vim.fn.bufnr()
  _layout:mount()
  vim.api.nvim_set_current_win(explorer.panel.winid)
  vim.g.dbridge_loaded = 1
  explorer.update_target()
  _hidden = false
  pcall(vim.api.nvim_buf_delete, tmp, { force = true })
end

function M.setup(opts)
  _cfg = vim.tbl_deep_extend("force", _cfg, opts or {})
end

M.open = open
M.close = teardown

vim.api.nvim_create_user_command("Dbridge", function()
  if vim.g.dbridge_loaded ~= 1 or not _layout then
    open()
  elseif _hidden then
    _layout:show()
    vim.api.nvim_set_current_win(explorer.panel.winid)
    _hidden = false
  else
    _layout:hide()
    _hidden = true
  end
end, { desc = "Toggle the dbridge UI" })

vim.api.nvim_create_user_command("DbridgeClose", function()
  teardown()
  client.stop()
end, { desc = "Close the dbridge UI and stop the server" })

-- Never build UI while Neovim is exiting; just reap the server process.
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    _tearing_down = true
    client.stop()
  end,
})

return M
