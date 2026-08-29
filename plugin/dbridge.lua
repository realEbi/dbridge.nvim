-- Plugin entry point: registers the nvim-cmp source if cmp is available.
-- The :Dbridge command is registered in lua/dbridge/init.lua (loaded on demand).
local ok, cmp = pcall(require, "cmp")
if ok then
  cmp.register_source("dbridge", require("dbridge.cmp"):new())
end
