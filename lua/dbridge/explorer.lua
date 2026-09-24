-- DB explorer panel: Profile → declared Scope Levels → table → column
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
    session_id = n._session_id, path = n._scope_path, name = n._table,
  }, function(result, err)
    vim.schedule(function()
      if M.tree ~= tree or tree:get_node(n:get_id()) ~= n
        or not M.panel or not M.panel.bufnr or not vim.api.nvim_buf_is_valid(M.panel.bufnr) then return end
      n._loading = false
      if err or not result then
        vim.notify("[dbridge] table metadata: " .. (err and err.message or "empty response"), vim.log.levels.ERROR)
        return
      end
      local identifier = result.sql_identifier
      if type(identifier) ~= "string" or identifier == "" then
        vim.notify("[dbridge] table metadata has no executable identifier; refresh the schema", vim.log.levels.ERROR)
        return
      end
      n._sql_identifier = identifier
      n._loaded = true
      for _, col in ipairs(result.columns or {}) do
        local detail = col.data_type .. (col.nullable and "" or " NOT NULL")
        tree:add_node(node(" " .. col.name, "column", { detail = detail, _scope_path = vim.deepcopy(n._scope_path) }), n:get_id())
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

local function build_schema_tree(n, session_id, current, declaration)
  local tree = M.tree
  local containers, paths, pending, failed = {}, {}, 1, false
  local levels = declaration.levels
  local function to_nodes(entries, depth)
    local nodes = {}
    for _, entry in ipairs(entries) do
      if depth > #levels then
        nodes[#nodes + 1] = node(" " .. entry.name, "table", {
          _session_id = session_id, _scope_path = vim.deepcopy(entry.path),
          _table = entry.name, _sql_identifier = entry.sql_identifier, _loaded = false,
        })
      else
        nodes[#nodes + 1] = node(" " .. entry.name, "scope", {
          _scope_path = vim.deepcopy(entry.path), _internal = entry.internal,
          detail = levels[depth].label .. (entry.internal and " (internal)" or ""),
        }, to_nodes(entry.children, depth + 1))
      end
    end
    return nodes
  end
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
      -- Keep the focused identity across replacement. Otherwise collapsing the
      -- new tree clamps a table's old row onto an unrelated scope, and the next
      -- CursorMoved event silently selects that scope for completion.
      local selected
      if M.panel.winid == vim.api.nvim_get_current_win() then
        selected = tree:get_node()
        if connection_root(selected) ~= n then selected = nil end
        if selected and selected._type == "column" then
          selected = tree:get_node(selected:get_parent_id())
        end
      end
      for _, child_id in ipairs(vim.deepcopy(n:get_child_ids())) do tree:remove_node(child_id) end
      for _, child in ipairs(to_nodes(containers, 1)) do tree:add_node(child, n:get_id()) end
      n._levels, n._default_path = vim.deepcopy(levels), vim.deepcopy(declaration.default_path)
      n._available_paths = paths
      if not paths[vim.json.encode(n._active_path)] then n._active_path = vim.deepcopy(n._default_path) end
      n:expand()
      local focus, scope = n, nil
      local function find_selected(parent)
        for _, child in ipairs(tree:get_nodes(parent:get_id())) do
          if vim.deep_equal(child._scope_path, selected._scope_path) then
            if child._type == "scope" then scope = child end
            if child._type == selected._type and child._table == selected._table then focus = child end
          end
          find_selected(child)
        end
      end
      if selected then
        find_selected(n)
        if focus == n and scope then focus = scope end
        local ancestor = focus
        while ancestor:get_parent_id() do
          ancestor = tree:get_node(ancestor:get_parent_id())
          ancestor:expand()
        end
      end
      tree:render()
      if selected then
        local _, row = tree:get_node(focus:get_id())
        vim.api.nvim_win_set_cursor(M.panel.winid, { row, 0 })
      end
      M.update_target()
    end)
  end
  local function list_children(entries, path, depth)
    local method = depth == 1 and "listDatabases" or (depth <= #levels and "listSchemas" or "listTables")
    local params = { session_id = session_id }
    if depth > 1 then params.path = path end
    client.request("dbridge/" .. method, params, function(result, err)
      if not current() then return end
      if not err then
        for i, item in ipairs(result or {}) do
          local child_path = vim.deepcopy(path)
          if depth <= #levels then child_path[#child_path + 1] = item.name end
          entries[i] = {
            name = item.name, internal = item.internal, path = child_path,
            sql_identifier = item.sql_identifier, children = {},
          }
          if depth <= #levels then
            if depth == #levels then paths[vim.json.encode(child_path)] = true end
            pending = pending + 1
            list_children(entries[i].children, child_path, depth + 1)
          end
        end
      end
      finish(err, method)
    end)
  end
  list_children(containers, {}, 1)
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
    n._session_dialect = result.dialect
    n._levels, n._default_path = vim.deepcopy(result.levels), vim.deepcopy(result.default_path)
    n._active_path = vim.deepcopy(result.default_path)
    build_schema_tree(n, sid, schema_load(n, sid), result)
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
  elseif t == "scope" then
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
  local function target(n, selected)
    if n and _sessions[n:get_id()] then
      if selected and selected._scope_path then
        n._active_path = vim.deepcopy(selected._scope_path)
        for i = #n._active_path + 1, #n._levels do n._active_path[i] = n._default_path[i] end
      end
      return {
        name = n._name, adapter = n._session_adapter, dialect = n._session_dialect,
        session_id = _sessions[n:get_id()], path = vim.deepcopy(n._active_path),
      }
    end
  end
  -- The explorer cursor selects a target only while its panel has focus;
  -- the editor uses the last interaction instead of an unrelated tree row.
  if M.panel and M.panel.winid == vim.api.nvim_get_current_win() then
    local selected = target(connection_root(M.tree:get_node()), M.tree:get_node())
    if selected then return selected end
  end
  if _active_id then
    local selected = target((M.tree:get_node(_active_id)))
    if selected then return selected end
  end
  for _, n in ipairs(M.tree:get_nodes()) do
    local selected = target(n)
    if selected then return selected end
  end
end

-- Scope belongs to each SQL buffer, keyed by live Session identity. The editor
-- updates its binding on explorer interaction; independent SQL buffers retain theirs.
function M.set_query_target(bufnr, target)
  local scopes = vim.b[bufnr].dbridge_scopes or {}
  if target then scopes[target.session_id] = vim.deepcopy(target.path) end
  vim.b[bufnr].dbridge_scopes = scopes
end

function M.get_query_target(bufnr)
  local target = M.get_active_target()
  if not target then return nil end
  local scopes = vim.b[bufnr].dbridge_scopes or {}
  local path = scopes[target.session_id]
  for _, root in ipairs(M.tree and M.tree:get_nodes() or {}) do
    if root._session_id == target.session_id and path and root._available_paths
      and not root._available_paths[vim.json.encode(path)] then path = root._default_path end
  end
  target.path = vim.deepcopy(path or target.path)
  M.set_query_target(bufnr, target)
  return target
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
        n._session_id, n._session_adapter, n._session_dialect, n._connecting = nil, nil, nil, nil
        n._levels, n._default_path, n._active_path, n._available_paths = nil, nil, nil, nil
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
  client.request("dbridge/refreshSchema", { session_id = sid }, function(result, err)
    if not current() then return end
    if err then vim.notify("[dbridge] refresh failed: " .. err.message, vim.log.levels.ERROR); return end
    build_schema_tree(n, sid, current, result)
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
