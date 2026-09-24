-- SQL editor panel
local Split = require("nui.split")
local M = {}
M.panel = nil

function M.get_sql()
  local mode = vim.api.nvim_get_mode().mode
  local bufnr = M.panel.bufnr
  if mode == "v" or mode == "V" then
    local s = vim.fn.getpos("'<")
    local e = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_text(bufnr, s[2]-1, s[3]-1, e[2]-1, e[3], {})
    return table.concat(lines, "\n")
  end
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

function M.get_statement()
  if not M.panel or vim.api.nvim_get_current_buf() ~= M.panel.bufnr then
    return nil, "Place the cursor in the dbridge query editor first"
  end
  local lines = vim.api.nvim_buf_get_lines(M.panel.bufnr, 0, -1, false)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local offset = col
  for line = 1, row - 1 do offset = offset + #lines[line] + 1 end
  local explorer = require("dbridge.explorer")
  local target = explorer.get_active_target and explorer.get_active_target()
  return require("dbridge.statements").at(table.concat(lines, "\n"), offset, target and target.dialect)
end

function M.set_sql(sql)
  vim.api.nvim_buf_set_lines(M.panel.bufnr, 0, -1, false, vim.split(sql, "\n"))
end

function M.update_target(target)
  if not M.panel or not M.panel.winid or not vim.api.nvim_win_is_valid(M.panel.winid) then return end
  require("dbridge.explorer").set_query_target(M.panel.bufnr, target)
  local text = " dbridge | No active Session "
  if target then
    local function literal(value)
      return tostring(value):gsub("[%c]", " "):gsub("%%", "%%%%")
    end
    text = " dbridge | " .. literal(target.name) .. " (" .. literal(target.adapter)
      .. ") | Session " .. literal(target.session_id) .. " | Scope " .. literal(table.concat(target.path or {}, " / ")) .. " "
  end
  vim.api.nvim_set_option_value("winbar", text, { win = M.panel.winid })
end

function M.init()
  M.panel = Split({
    buf_options = { filetype = "sql", buftype = "", swapfile = false },
    enter = false,
  })
  M.panel:on("BufEnter", function()
    vim.opt_local.commentstring = "-- %s"
  end)
  M.panel:on("QuitPre", function()
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = M.panel.bufnr })
  end)
end

return M
