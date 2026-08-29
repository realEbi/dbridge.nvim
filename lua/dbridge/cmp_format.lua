-- Optional formatter for the nvim-cmp menu; see README.
-- Reads `completion_item.type`, which dbridge.cmp carries over from the
-- server's string kind ("table" | "column" | "keyword").
local M = {}
local icons = { table = "", column = "", keyword = "󰌋", database = "", schema = "󰢶" }

M.build_format = function(entry, vim_item)
  local kind = entry.completion_item.type
  if type(kind) == "string" then
    local key = kind:lower()
    vim_item.kind = (icons[key] or "") .. " " .. key
  end
  vim_item.menu = "[DBRIDGE]"
  return vim_item
end

return M
