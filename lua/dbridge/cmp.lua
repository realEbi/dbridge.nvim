-- Optional nvim-cmp source for dbridge SQL completion
local client = require("dbridge.client")
local explorer = require("dbridge.explorer")

local source = {}

function source:new()
  return setmetatable({}, { __index = self })
end

function source:is_available()
  return vim.bo.filetype == "sql" and client.is_running()
end

function source:get_debug_name() return "dbridge" end

function source:complete(params, callback)
  local session_id = explorer.get_active_session()
  if not session_id then callback({ items = {} }); return end
  local sql = params.context.cursor_before_line
  client.request("dbridge/complete", { session_id = session_id, sql = sql }, function(result, _)
    if not result then callback({ items = {} }); return end
    local items = {}
    local kind_map = {
      table = vim.lsp.protocol.CompletionItemKind.Class,
      column = vim.lsp.protocol.CompletionItemKind.Field,
      keyword = vim.lsp.protocol.CompletionItemKind.Keyword,
    }
    for _, item in ipairs(result) do
      table.insert(items, {
        label = item.label,
        kind = kind_map[item.kind] or vim.lsp.protocol.CompletionItemKind.Text,
        detail = item.detail,
        -- carried for dbridge.cmp_format, which the README documents
        type = item.kind,
      })
    end
    callback({ items = items, isIncomplete = false })
  end)
end

return source
