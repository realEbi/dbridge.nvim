-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

--- Put a dependency on the runtimepath, preferring the vendored copy in deps/.
local function add_dep(name, hint)
  local vendored = vim.fn.getcwd() .. "/deps/" .. name
  if vim.fn.isdirectory(vendored) == 1 then
    vim.opt.rtp:append(vendored)
    return true
  end
  -- Fall back to a plugin manager's install location.
  for _, dir in ipairs(vim.fn.globpath(vim.fn.stdpath("data"), "*/" .. name, false, true)) do
    if vim.fn.isdirectory(dir) == 1 then
      vim.opt.rtp:append(dir)
      return true
    end
  end
  error(("missing dependency %q — run `%s`"):format(name, hint))
end

if #vim.api.nvim_list_uis() == 0 then
  add_dep("mini.nvim", "make deps/mini.nvim")
  add_dep("nui.nvim", "make deps/nui.nvim")
  require("mini.test").setup()
end
