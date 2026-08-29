-- Query results panel with client-side pagination.
local Split = require("nui.split")
local NuiTable = require("nui.table")
local NuiText = require("nui.text")

local M = {}
M.panel = nil

local PAGE = 20

local _columns = {} -- ordered column names, as sent by the server
local _rows = {}    -- list of row-lists, positionally aligned with _columns
local _warnings = {}
local _page = 0

--- JSON null decodes to vim.NIL, which is truthy in Lua, so `or ""` misses it.
local function display(value)
  if value == nil or value == vim.NIL then return "NULL" end
  return tostring(value)
end

local function total_pages()
  if #_rows == 0 then return 0 end
  return math.ceil(#_rows / PAGE) - 1
end

local function set_lines(lines)
  if not M.panel or not M.panel.bufnr then return end
  vim.api.nvim_set_option_value("modifiable", true, { buf = M.panel.bufnr })
  vim.api.nvim_buf_set_lines(M.panel.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = M.panel.bufnr })
end

local function set_status(text)
  -- winid is nil when the panel exists but is not mounted.
  if not M.panel or not M.panel.winid then return end
  if not vim.api.nvim_win_is_valid(M.panel.winid) then return end
  vim.api.nvim_set_option_value("statusline", text, { win = M.panel.winid })
end

local function render_page()
  if #_rows == 0 then
    set_lines({ "(no results)" })
    set_status(#_warnings > 0 and (" " .. table.concat(_warnings, "; ")) or " 0 rows")
    return
  end

  local first = _page * PAGE + 1
  local last = math.min(first + PAGE - 1, #_rows)

  -- Build columns from the server's ordered column list, not from the keys of a
  -- Lua table: pairs() order is unspecified and scrambles the column layout.
  local columns = {}
  for idx, name in ipairs(_columns) do
    table.insert(columns, {
      align = "left",
      header = name,
      accessor_key = tostring(idx),
      cell = function(cell)
        return NuiText(display(cell.get_value()))
      end,
    })
  end

  -- NuiTable wants records; key them by column index so order comes from
  -- `columns` above and duplicate column names cannot collide.
  local data = {}
  for i = first, last do
    local record = {}
    for idx = 1, #_columns do
      record[tostring(idx)] = _rows[i][idx]
    end
    table.insert(data, record)
  end

  set_lines({})
  NuiTable({
    bufnr = M.panel.bufnr,
    ns_id = M.panel.ns_id,
    columns = columns,
    data = data,
  }):render()

  local status = string.format(
    " page %d/%d  rows %d-%d of %d",
    _page + 1, total_pages() + 1, first, last, #_rows
  )
  if #_warnings > 0 then
    status = status .. "  ⚠ " .. table.concat(_warnings, "; ")
  end
  set_status(status)
end

--- Render a QueryResult: { columns, rows, row_count, execution_time_ms, warnings }
function M.render(query_result)
  _page = 0
  _columns = (query_result and query_result.columns) or {}
  _rows = (query_result and query_result.rows) or {}
  _warnings = (query_result and query_result.warnings) or {}

  -- Truncation is reported by the server and is easy to miss otherwise: the
  -- page counter alone makes a capped result look complete.
  for _, w in ipairs(_warnings) do
    vim.notify("[dbridge] " .. w, vim.log.levels.WARN)
  end

  render_page()
end

function M.next_page()
  if _page < total_pages() then
    _page = _page + 1
    render_page()
  else
    vim.notify("[dbridge] last page")
  end
end

function M.prev_page()
  if _page > 0 then
    _page = _page - 1
    render_page()
  else
    vim.notify("[dbridge] first page")
  end
end

function M.init()
  M.panel = Split({ enter = false })
end

return M
