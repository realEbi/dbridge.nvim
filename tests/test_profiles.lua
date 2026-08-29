-- Profile CRUD over the protocol, plus connect-by-profile.
local H = require("tests.helpers")
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()
local config_dir

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() config_dir = H.boot(child) end,
    post_once = function() H.shutdown(child) end,
  },
})

local function profile(name, ...)
  local r = child.lua_get("_E.profile_call(...)", { name, ... })
  if r.err == false then r.err = nil end
  return r.result, r.err, r.done
end

T["starts with no profiles in an isolated config"] = function()
  local r, err = profile("list")
  eq(err, nil)
  eq(vim.tbl_count(r), 0)
end

T["save then list round-trips"] = function()
  local _, err = profile("save", "alpha", "sqlite", { uri = ":memory:" })
  eq(err, nil)
  local listed = profile("list")
  eq(listed.alpha, { adapter = "sqlite", config = { uri = ":memory:" } })
end

T["save upserts without clobbering siblings"] = function()
  profile("save", "beta", "duckdb", { uri = ":memory:" })
  profile("save", "alpha", "duckdb", { uri = "/tmp/a.duckdb" })
  local listed = profile("list")
  eq(listed.alpha.adapter, "duckdb")
  eq(listed.alpha.config.uri, "/tmp/a.duckdb")
  eq(listed.beta.adapter, "duckdb")
end

T["delete removes only the named profile"] = function()
  eq(profile("delete", "beta").ok, true)
  local listed = profile("list")
  eq(listed.beta, nil)
  eq(listed.alpha ~= nil, true)
end

T["deleting a missing profile reports ok=false"] = function()
  eq(profile("delete", "never-existed").ok, false)
end

T["connect by profile name"] = function()
  profile("save", "mem", "sqlite", { uri = ":memory:" })
  local r, err = H.request(child, "dbridge/connect", { profile = "mem" }, 30000)
  eq(err, nil)
  eq(type(r.session_id), "string")

  child.lua("_E.exec(...)", { r.session_id, "CREATE TABLE viaprofile (id INTEGER)" })
  eq(H.request(child, "dbridge/listTables", { session_id = r.session_id }), { "viaprofile" })
end

T["connect by inline adapter and config"] = function()
  local r, err = H.request(child, "dbridge/connect",
    { adapter = "sqlite", config = { uri = ":memory:" } }, 30000)
  eq(err, nil)
  eq(type(r.session_id), "string")
end

T["profiles persist to disk for the next server"] = function()
  profile("save", "durable", "sqlite", { uri = ":memory:" })
  local toml = config_dir .. "/dbridge/connections.toml"
  eq(vim.fn.filereadable(toml), 1)
  eq(table.concat(vim.fn.readfile(toml), "\n"):find("durable", 1, true) ~= nil, true)
end

return T
