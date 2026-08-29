-- Query results panel with simple pagination
local Split = require("nui.split")
local NuiTable = require("nui.table")
local NuiText = require("nui.text")
local M = {}
M.panel = nil

local PAGE = 20
local _data = {}
local _page = 0

local function total_pages()
  return math.max(0, math.ceil(#_data / PAGE) - 1)
end

local function render_page()
  if #_data == 0 then
    vim.api.nvim_set_option_value("modifiable", true, { buf = M.panel.bufnr })
    vim.api.nvim_buf_set_lines(M.panel.bufnr, 0, -1, false, { "(no results)" })
    vim.api.nvim_set_option_value("modifiable", false, { buf = M.panel.bufnr })
    return
  end
  local s = _page * PAGE + 1
  local e = math.min(s + PAGE - 1, #_data)
  local slice = vim.list_slice(_data, s, e)
  local columns = {}
  for k in pairs(slice[1]) do
    table.insert(columns, {
      align = "left", header = k, accessor_key = k,
      cell = function(c) return NuiText(tostring(c.get_value() or "")) end,
    })
  end
  vim.api.nvim_set_option_value("modifiable", true, { buf = M.panel.bufnr })
  vim.api.nvim_buf_set_lines(M.panel.bufnr, 0, -1, false, {})
  vim.api.nvim_set_option_value("modifiable", false, { buf = M.panel.bufnr })
  NuiTable({ bufnr = M.panel.bufnr, ns_id = M.panel.ns_id, columns = columns, data = slice }):render()
  vim.api.nvim_win_set_option(M.panel.winid, "statusline",
    string.format(" page %d/%d  rows %d-%d of %d", _page+1, total_pages()+1, s, e, #_data))
end

function M.render(query_result)
  -- query_result: {columns, rows} where rows is list of lists
  _page = 0
  _data = {}
  if query_result and query_result.rows then
    local cols = query_result.columns or {}
    for _, row in ipairs(query_result.rows) do
      local record = {}
      for i, col in ipairs(cols) do record[col] = row[i] end
      table.insert(_data, record)
    end
  end
  render_page()
end

function M.next_page()
  if _page < total_pages() then _page = _page + 1; render_page()
  else vim.notify("[dbridge] last page") end
end

function M.prev_page()
  if _page > 0 then _page = _page - 1; render_page()
  else vim.notify("[dbridge] first page") end
end

function M.init()
  M.panel = Split({ enter = false })
end

return M
