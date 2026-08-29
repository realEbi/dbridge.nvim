-- Optional nvim-cmp menu formatter.
--
-- nvim-cmp renders the generic LSP kind name, so a table shows up as "Class"
-- and a column as "Field". This maps back to dbridge's own vocabulary. Wire it
-- up in your cmp config; see the README.
local M = {}

local ICONS = {
  table = "",
  column = "",
  keyword = "󰌋",
  database = "",
  schema = "󰢶",
}

--- Format a dbridge completion entry. Leaves non-dbridge entries untouched.
function M.build_format(entry, vim_item)
  local kind = (entry.completion_item or {}).dbridge_kind
  if type(kind) == "string" and kind ~= "" then
    local icon = ICONS[kind]
    vim_item.kind = (icon and (icon .. " ") or "") .. kind
  end
  vim_item.menu = "[DBRIDGE]"
  return vim_item
end

return M
