-- nvim-cmp source backed by dbridge/complete.
local client = require("dbridge.client")
local explorer = require("dbridge.explorer")

local source = {}

function source:new()
  return setmetatable({}, { __index = self })
end

function source:is_available()
  return vim.bo.filetype == "sql" and client.is_running()
end

function source:get_debug_name()
  return "dbridge"
end

function source:get_trigger_characters()
  return { "." }
end

function source:get_position_encoding_kind()
  return "utf-8"
end

-- Capture the whole post-dot identifier, including text after the cursor.
-- A plain textEdit replaces this range even with cmp's default Insert behavior.
local function qualified_column_range(sql, position)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  -- SQL permits whitespace (including a newline) between dot and identifier.
  local start = vim.fn.match(sql:sub(1, position), [[\.\_s*\zs\k*$]])
  if start == -1 then return nil end
  local suffix = vim.fn.matchstr(sql:sub(position + 1), [[^\k*]])
  return {
    start = { line = row - 1, character = col - (position - start) },
    ["end"] = { line = row - 1, character = col + #suffix },
  }
end

--- Byte offset of the cursor within the whole buffer joined by "\n".
--- The server expects a UTF-8 byte offset, which is what Neovim reports for
--- the cursor column, so no conversion is needed beyond adding the newlines.
local function cursor_byte_offset(bufnr)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row - 1, false)
  local offset = 0
  for _, line in ipairs(lines) do
    offset = offset + #line + 1 -- +1 for the "\n" that joins it to the next
  end
  return offset + col
end

function source:complete(params, callback)
  local session_id = explorer.get_active_session()
  if not session_id then
    callback({ items = {} })
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  -- Send the whole buffer plus the cursor offset. Sending only the text before
  -- the cursor would hide the FROM clause on a later line, which is exactly
  -- what the server needs to resolve columns.
  local sql = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  local position = cursor_byte_offset(bufnr)
  local column_range = qualified_column_range(sql, position)

  -- Only the newest request may answer; fast typing otherwise lets a stale
  -- reply overwrite a fresher one.
  self._seq = (self._seq or 0) + 1
  local seq = self._seq

  client.request("dbridge/complete", { session_id = session_id, sql = sql, position = position },
    function(result, _)
      if seq ~= self._seq then return end
      if not result then
        callback({ items = {} })
        return
      end
      local kind_map = {
        table = vim.lsp.protocol.CompletionItemKind.Class,
        column = vim.lsp.protocol.CompletionItemKind.Field,
        keyword = vim.lsp.protocol.CompletionItemKind.Keyword,
      }
      local items = {}
      for _, item in ipairs(result) do
        local completion_item = {
          label = item.label,
          kind = kind_map[item.kind] or vim.lsp.protocol.CompletionItemKind.Text,
          detail = item.detail,
          insertText = item.insert_text,
          sortText = item.sort_key,
          -- dbridge's own kind, kept alongside the LSP one so cmp_format can
          -- render "table"/"column" rather than "Class"/"Field"
          dbridge_kind = item.kind,
        }
        if item.kind == "column" and column_range then
          completion_item.textEdit = {
            range = column_range,
            newText = item.insert_text,
          }
        end
        table.insert(items, completion_item)
      end
      callback({ items = items, isIncomplete = false })
    end)
end

return source
