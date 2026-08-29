-- DB explorer panel: NuiTree with CONNECTION→DATABASE→SCHEMA→TABLE→COLUMN
local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")
local Split = require("nui.split")
local client = require("dbridge.client")
local profiles = require("dbridge.profiles")

local M = {}
M.panel = nil
M.tree = nil

-- active session per connection node id
local _sessions = {}

local function node(text, type, extra, children)
  local data = vim.tbl_extend("force", { text = text, _type = type }, extra or {})
  return NuiTree.Node(data, children or {})
end

local function render() M.tree:render() end

local function add_column_nodes(parent_id, session_id, fqn)
  client.request("dbridge/getTableSchema", { session_id = session_id, fqn = fqn }, function(result, err)
    if err or not result then return end
    for _, col in ipairs(result.columns or {}) do
      local detail = col.data_type .. (col.nullable and "" or " NOT NULL")
      M.tree:add_node(node(" " .. col.name, "column", { detail = detail }), parent_id)
    end
    vim.schedule(render)
  end)
end

local function expand_table(n)
  if n._loaded then
    n:expand(); render(); return
  end
  n._loaded = true
  add_column_nodes(n:get_id(), n._session_id, n._fqn)
  n:expand(); render()
end

local function build_schema_tree(conn_node_id, session_id)
  -- list databases
  client.request("dbridge/listDatabases", { session_id = session_id }, function(dbs, err)
    if err then
      vim.notify("[dbridge] listDatabases: " .. err.message, vim.log.levels.ERROR); return
    end
    for _, db in ipairs(dbs or {}) do
      local db_node = node(" " .. db, "database")
      M.tree:add_node(db_node, conn_node_id)
      -- list schemas per db
      client.request("dbridge/listSchemas", { session_id = session_id, database = db }, function(schemas, e2)
        if e2 then return end
        for _, sc in ipairs(schemas or {}) do
          local sc_node = node("󰢶 " .. sc, "schema")
          M.tree:add_node(sc_node, db_node:get_id())
          -- list tables per schema
          client.request("dbridge/listTables", { session_id = session_id, database = db, schema = sc }, function(tables, e3)
            if e3 then return end
            for _, tbl in ipairs(tables or {}) do
              local fqn = db .. "." .. sc .. "." .. tbl
              local tbl_node = node(" " .. tbl, "table", {
                _session_id = session_id, _fqn = fqn, _loaded = false,
              })
              M.tree:add_node(tbl_node, sc_node:get_id())
            end
            vim.schedule(render)
          end)
        end
        vim.schedule(render)
      end)
    end
    vim.schedule(render)
  end)
end

local function connect_profile(n)
  -- already connected: just toggle
  if _sessions[n:get_id()] then
    if n:is_expanded() then n:collapse() else n:expand() end
    render(); return
  end
  client.request("dbridge/connect", { adapter = n._adapter, config = n._config }, function(result, err)
    if err then
      vim.notify("[dbridge] connect failed: " .. err.message, vim.log.levels.ERROR); return
    end
    local sid = result.session_id
    _sessions[n:get_id()] = sid
    n._session_id = sid
    build_schema_tree(n:get_id(), sid)
    n:expand(); vim.schedule(render)
  end)
end

function M.add_profile_node(name, adapter, config)
  local n = node("󱘖 " .. name, "connection", {
    _name = name, _adapter = adapter, _config = config or {},
  })
  M.tree:add_node(n)
  render()
  return n
end

function M.handle_enter()
  local n = M.tree:get_node()
  if not n then return end
  local t = n._type
  if t == "connection" then
    connect_profile(n)
  elseif t == "table" then
    if not n._loaded then expand_table(n)
    else
      if n:is_expanded() then n:collapse() else n:expand() end
      render()
    end
    -- return table info so init.lua can trigger a sample query
    return n
  elseif t == "database" or t == "schema" then
    if n:is_expanded() then n:collapse() else n:expand() end
    render()
  end
end

function M.get_active_session()
  -- return session_id of the first expanded connection
  local roots = M.tree:get_nodes()
  for _, n in ipairs(roots) do
    if n:is_expanded() and _sessions[n:get_id()] then
      return _sessions[n:get_id()]
    end
  end
end

function M.handle_add_profile()
  profiles.create_interactive(function(name, adapter, config)
    -- avoid duplicate nodes if profile already in tree
    for _, n in ipairs(M.tree:get_nodes()) do
      if n._name == name then
        n._adapter = adapter; n._config = config
        n.text = "󱘖 " .. name
        vim.schedule(render); return
      end
    end
    M.add_profile_node(name, adapter, config)
  end)
end

function M.handle_edit_profile()
  local n = M.tree:get_node()
  if not n or n._type ~= "connection" then return end
  profiles.create_interactive(function(name, adapter, config)
    -- update node text and stored config in-place
    n.text = "󱘖 " .. name
    n._name = name
    n._adapter = adapter
    n._config = config
    vim.schedule(render)
  end, { name = n._name, adapter = n._adapter, config = n._config })
end

function M.handle_delete()
  local n = M.tree:get_node()
  if not n or n._type ~= "connection" then return end
  profiles.delete(n._name, function(_, err)
    if err then
      vim.notify("[dbridge] delete failed: " .. err.message, vim.log.levels.ERROR); return
    end
    -- disconnect session if active
    local sid = _sessions[n:get_id()]
    if sid then
      client.request("dbridge/disconnect", { session_id = sid }, function() end)
      _sessions[n:get_id()] = nil
    end
    M.tree:remove_node(n:get_id())
    vim.schedule(render)
  end)
end

function M.handle_refresh()
  local n = M.tree:get_node()
  if not n then return end
  -- walk up to connection root
  while n._type ~= "connection" do
    local pid = n:get_parent_id()
    if not pid then return end
    n = M.tree:get_node(pid)
    if not n then return end
  end
  local sid = _sessions[n:get_id()]
  if not sid then return end
  client.request("dbridge/refreshSchema", { session_id = sid }, function(_, err)
    if err then vim.notify("[dbridge] refresh failed: " .. err.message, vim.log.levels.ERROR); return end
    -- remove all children and re-fetch
    for _, child_id in ipairs(n:get_child_ids()) do
      M.tree:remove_node(child_id)
    end
    _sessions[n:get_id()] = nil
    n._session_id = nil
    connect_profile(n)
  end)
end

function M.init()
  M.panel = Split({ enter = true })
  local opts = { noremap = true, nowait = true }
  M.tree = NuiTree({
    winid = M.panel.winid,
    bufnr = M.panel.bufnr,
    nodes = {},
    prepare_node = function(n)
      local line = NuiLine()
      line:append(string.rep("  ", n:get_depth() - 1))
      if n:has_children() then
        line:append(n:is_expanded() and " " or " ", "SpecialChar")
      else
        line:append("  ")
      end
      line:append(n.text)
      if n.detail then line:append("  " .. n.detail, "Comment") end
      return line
    end,
  })
  -- expand/collapse with l/h
  M.panel:map("n", "l", function()
    local n = M.tree:get_node()
    if n and n:expand() then render() end
  end, opts)
  M.panel:map("n", "h", function()
    local n = M.tree:get_node()
    if n and n:collapse() then render() end
  end, opts)

  -- Load saved profiles into the tree. No need to wait for the server to be
  -- ready: the request queues on the job's stdin and is answered once it is.
  profiles.list(function(result, err)
    if err then
      vim.notify("[dbridge] listProfiles: " .. err.message, vim.log.levels.ERROR)
      return
    end
    vim.schedule(function()
      for name, p in pairs(result or {}) do
        M.add_profile_node(name, p.adapter, p.config)
      end
    end)
  end)
end

return M
