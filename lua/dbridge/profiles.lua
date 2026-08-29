-- Profile management: list/save/delete via dbridge/listProfiles etc.
local client = require("dbridge.client")
local M = {}

function M.list(cb)
  client.request("dbridge/listProfiles", {}, cb)
end

function M.save(name, adapter, config, cb)
  client.request("dbridge/saveProfile", { name = name, adapter = adapter, config = config or {} }, cb)
end

function M.delete(name, cb)
  client.request("dbridge/deleteProfile", { name = name }, cb)
end

-- Interactive: prompt user for profile fields, then save.
-- Pass defaults to pre-fill prompts when editing an existing profile.
function M.create_interactive(on_done, defaults)
  defaults = defaults or {}
  vim.ui.input({ prompt = "Profile name: ", default = defaults.name or "" }, function(name)
    if not name or name == "" then return end
    vim.ui.input({ prompt = "Adapter (sqlite/duckdb/...): ", default = defaults.adapter or "" }, function(adapter)
      if not adapter or adapter == "" then return end
      local cfg_default = (defaults.config and vim.fn.json_encode(defaults.config)) or ""
      vim.ui.input({ prompt = "Config (JSON): ", default = cfg_default }, function(cfg_str)
        local config = {}
        if cfg_str and cfg_str ~= "" then
          local ok, parsed = pcall(vim.fn.json_decode, cfg_str)
          if ok then config = parsed end
        end
        M.save(name, adapter, config, function(_, err)
          if err then
            vim.notify("[dbridge] save profile failed: " .. err.message, vim.log.levels.ERROR)
          else
            vim.notify("[dbridge] profile '" .. name .. "' saved")
            if on_done then on_done(name, adapter, config) end
          end
        end)
      end)
    end)
  end)
end

return M
