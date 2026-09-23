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

function M.update_target()
  if M.on_active_changed then M.on_active_changed(M.get_active_target()) end
end

local function render()
  M.tree:render()
  M.update_target()
end

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

-- Gather a complete replacement off-tree. A failed or superseded load must not
-- erase the last usable metadata view or mutate a removed/recreated tree.
local function schema_load(n, session_id)
  local tree = M.tree
  n._schema_generation = (n._schema_generation or 0) + 1
  local generation = n._schema_generation
  return function()
    return M.tree == tree and tree:get_node(n:get_id()) == n
      and M.panel and M.panel.bufnr and vim.api.nvim_buf_is_valid(M.panel.bufnr)
      and _sessions[n:get_id()] == session_id and n._schema_generation == generation
  end
end

local function build_schema_tree(n, session_id, current)
  local tree = M.tree
  local databases, pending, failed = {}, 1, false
  local function finish(err, method)
    if not current() then return end
    if err and not failed then
      failed = true
      vim.notify("[dbridge] " .. method .. ": " .. err.message, vim.log.levels.ERROR)
    end
    pending = pending - 1
    if pending ~= 0 or failed then return end
    vim.schedule(function()
      if not current() then return end
      for _, child_id in ipairs(vim.deepcopy(n:get_child_ids())) do tree:remove_node(child_id) end
      for _, db in ipairs(databases) do
        local schemas = {}
        for _, sc in ipairs(db.schemas) do
          local tables = {}
          for _, tbl in ipairs(sc.tables) do
            tables[#tables + 1] = node(" " .. tbl, "table", {
              _session_id = session_id,
              _fqn = db.name .. "." .. sc.name .. "." .. tbl,
              _table = tbl,
              _table_ref = { name = tbl, database = db.name, schema = sc.name },
              _loaded = false,
            })
          end
          schemas[#schemas + 1] = node("󰢶 " .. sc.name, "schema", nil, tables)
        end
        tree:add_node(node(" " .. db.name, "database", nil, schemas), n:get_id())
      end
      n:expand()
      render()
    end)
  end
  client.request("dbridge/listDatabases", { session_id = session_id }, function(dbs, err)
    if not current() then return end
    if not err then
      for i, db in ipairs(dbs or {}) do
        local entry = { name = db, schemas = {} }
        databases[i] = entry
        pending = pending + 1
        client.request("dbridge/listSchemas", { session_id = session_id, database = db }, function(schemas, e2)
          if not current() then return end
          if not e2 then
            for j, sc in ipairs(schemas or {}) do
              local schema = { name = sc, tables = {} }
              entry.schemas[j] = schema
              pending = pending + 1
              client.request("dbridge/listTables", { session_id = session_id, database = db, schema = sc }, function(tables, e3)
                if not current() then return end
                schema.tables = tables or {}
                finish(e3, "listTables")
              end)
            end
          end
          finish(e2, "listSchemas")
        end)
      end
    end
    finish(err, "listDatabases")
  end)
end

local function connect_profile(n)
  -- already connected: just toggle
  if _sessions[n:get_id()] then
    _active_id = n:get_id()
    if n:is_expanded() then n:collapse() else n:expand() end
    render(); return
  end
  if n._connecting then return end
  n._connecting = true
  local tree, adapter = M.tree, n._adapter
  client.request("dbridge/connect", { adapter = adapter, config = n._config }, function(result, err)
    n._connecting = false
    if M.tree ~= tree or tree:get_node(n:get_id()) ~= n
      or not M.panel or not M.panel.bufnr or not vim.api.nvim_buf_is_valid(M.panel.bufnr) then
      if result then client.request("dbridge/disconnect", { session_id = result.session_id }, function() end) end
      return
    end
    if err then
      vim.notify("[dbridge] connect failed: " .. err.message, vim.log.levels.ERROR); return
    end
    local sid = result.session_id
    _sessions[n:get_id()] = sid
    _active_id = n:get_id()
    n._session_id = sid
    n._session_adapter = adapter
    build_schema_tree(n, sid, schema_load(n, sid))
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
function M.get_active_target()
  if not M.tree or not client.is_running() then return nil end
  local function target(n)
    if n and _sessions[n:get_id()] then
      return { name = n._name, adapter = n._session_adapter, session_id = _sessions[n:get_id()] }
    end
  end
  -- The explorer cursor selects a target only while its panel has focus;
  -- the editor uses the last interaction instead of an unrelated tree row.
  if M.panel and M.panel.winid == vim.api.nvim_get_current_win() then
    local selected = target(connection_root(M.tree:get_node()))
    if selected then return selected end
  end
  if _active_id then
    local selected = target(M.tree:get_node(_active_id))
    if selected then return selected end
  end
  for _, n in ipairs(M.tree:get_nodes()) do
    local selected = target(n)
    if selected then return selected end
  end
end

function M.get_active_session()
  local target = M.get_active_target()
  return target and target.session_id
end

-- Session IDs belong to the child process. A known stop invalidates every
-- binding and its metadata even when a new process is started later.
function M.server_state_changed(running)
  if not running then
    _sessions, _active_id = {}, nil
    if M.tree then
      for _, n in ipairs(M.tree:get_nodes()) do
        n._session_id, n._session_adapter, n._connecting = nil, nil, nil
        n._schema_generation = (n._schema_generation or 0) + 1
        for _, child_id in ipairs(vim.deepcopy(n:get_child_ids())) do M.tree:remove_node(child_id) end
        n:collapse()
      end
      if M.panel and M.panel.bufnr and vim.api.nvim_buf_is_valid(M.panel.bufnr) then render() end
    end
  end
  M.update_target()
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
  local n = connection_root(M.tree:get_node())
  if not n then return end
  local sid = _sessions[n:get_id()]
  if not sid then return end
  _active_id = n:get_id()
  M.update_target()
  local current = schema_load(n, sid)
  client.request("dbridge/refreshSchema", { session_id = sid }, function(_, err)
    if not current() then return end
    if err then vim.notify("[dbridge] refresh failed: " .. err.message, vim.log.levels.ERROR); return end
    build_schema_tree(n, sid, current)
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
    if n:expand() then render() else M.update_target() end
  end, opts)
  M.panel:map("n", "h", function()
    local n = M.tree:get_node()
    if not n then return end
    mark_active(n)
    if n:collapse() then render() else M.update_target() end
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
