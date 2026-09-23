-- Runtime init for the child Neovim instances that mini.test spawns.
-- Only sets up the runtimepath; the parent drives everything else over RPC.
vim.cmd([[let &rtp.=','.getcwd()]])

local function add_dep(name)
  local vendored = vim.fn.getcwd() .. "/deps/" .. name
  if vim.fn.isdirectory(vendored) == 1 then
    vim.opt.rtp:append(vendored)
    return
  end
  for _, dir in ipairs(vim.fn.globpath(vim.fn.stdpath("data"), "*/" .. name, false, true)) do
    if vim.fn.isdirectory(dir) == 1 then
      vim.opt.rtp:append(dir)
      return
    end
  end
  error("missing dependency: " .. name)
end

add_dep("nui.nvim")
add_dep("nvim-cmp")
