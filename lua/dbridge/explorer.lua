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
-- id of the connection the user last interacted with; disambiguates which
-- session <leader>r targets when several profiles are connected at once
local _active_id = nil

local function node(text, type, extra, children)
  local data = vim.tbl_extend("force", { text = text, _type = type }, extra or {})
  return NuiTree.Node(data, children or {})
end

local function render() M.tree:render() end

--- Walk up from any node to the connection root it belongs to.
local function connection_root(n)
  while n and n._type ~= "connection" do
    local pid = n:get_parent_id()
    if not pid then return nil end
    n = M.tree:get_node(pid)
  end
  return n
end

local function load_table(n, on_ready)
  if n._loading then return end
  local tree = M.tree
  n._loading = true
  client.request("dbridge/getTableSchema", {
    session_id = n._session_id, fqn = n._fqn, table = n._table_ref,
  }, function(result, err)
    vim.schedule(function()
      if M.tree ~= tree or tree:get_node(n:get_id()) ~= n
        or not M.panel or not M.panel.bufnr or not vim.api.nvim_buf_is_valid(M.panel.bufnr) then return end
      n._loading = false
      if err or not result then
        vim.notify("[dbridge] table metadata: " .. (err and err.message or "empty response"), vim.log.levels.ERROR)
        return
      end
      -- A missing field identifies an older server. Explicit null/empty values
      -- from an updated server must never turn into a guessed bare-table query.
      local identifier = result.sql_identifier
      if identifier == nil then identifier = n._table end
      if type(identifier) ~= "string" or identifier == "" then
        vim.notify("[dbridge] table metadata has no executable identifier; refresh the schema", vim.log.levels.ERROR)
        return
      end
      n._sql_identifier = identifier
      n._loaded = true
      for _, col in ipairs(result.columns or {}) do
        local detail = col.data_type .. (col.nullable and "" or " NOT NULL")
        tree:add_node(node(" " .. col.name, "column", { detail = detail }), n:get_id())
      end
      n:expand()
      render()
      if on_ready then on_ready(n) end
    end)
  end)
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
                _session_id = session_id,
                _fqn = fqn,      -- database.schema.table, for getTableSchema
                _table = tbl,    -- display name and older-server fallback
                _table_ref = { name = tbl, database = db, schema = sc },
                _loaded = false,
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
    _active_id = n:get_id()
    if n:is_expanded() then n:collapse() else n:expand() end
    render(); return
  end
  client.request("dbridge/connect", { adapter = n._adapter, config = n._config }, function(result, err)
    if err then
      vim.notify("[dbridge] connect failed: " .. err.message, vim.log.levels.ERROR); return
    end
    local sid = result.session_id
    _sessions[n:get_id()] = sid
    _active_id = n:get_id()
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

function M.handle_enter(on_table_ready)
  local n = M.tree:get_node()
  if not n then return end
  local root = connection_root(n)
  if root and _sessions[root:get_id()] then _active_id = root:get_id() end
  local t = n._type
  if t == "connection" then
    connect_profile(n)
  elseif t == "table" then
    if not n._loaded then
      load_table(n, on_table_ready)
    else
      if n:is_expanded() then n:collapse() else n:expand() end
      render()
      if on_table_ready then on_table_ready(n) end
    end
    return n
  elseif t == "database" or t == "schema" then
    if n:is_expanded() then n:collapse() else n:expand() end
    render()
  end
end

--- Session that queries run against.
---
--- Prefers the connection under the cursor, then the one the user last
--- interacted with, then any connected one. Returning "the first expanded
--- connection" silently sent queries to the wrong database whenever more than
--- one profile was connected.
function M.get_active_session()
  -- tree:get_node() reads the CURRENT window's cursor, so it is only meaningful
  -- while the explorer is focused. <leader>r fires from the editor panel, where
  -- it would resolve against the wrong window.
  if M.panel and M.panel.winid == vim.api.nvim_get_current_win() then
    local under_cursor = connection_root(M.tree:get_node())
    if under_cursor and _sessions[under_cursor:get_id()] then
      return _sessions[under_cursor:get_id()]
    end
  end
  if _active_id and _sessions[_active_id] then
    return _sessions[_active_id]
  end
  for _, n in ipairs(M.tree:get_nodes()) do
    if _sessions[n:get_id()] then return _sessions[n:get_id()] end
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
      if _active_id == n:get_id() then _active_id = nil end
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
  local function mark_active(n)
    local root = connection_root(n)
    if root and _sessions[root:get_id()] then _active_id = root:get_id() end
  end
  M.panel:map("n", "l", function()
    local n = M.tree:get_node()
    if not n then return end
    mark_active(n)
    if n:expand() then render() end
  end, opts)
  M.panel:map("n", "h", function()
    local n = M.tree:get_node()
    if not n then return end
    mark_active(n)
    if n:collapse() then render() end
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
