-- Loaded INSIDE the child Neovim. The parent calls these over RPC, so all the
-- blocking (vim.wait) happens here rather than re-entering MiniTest's scheduler
-- in the parent.
local E = {}

local client

--- Boot the plugin against a real server. `opts.ui` also mounts the UI.
function E.boot(opts)
  opts = opts or {}
  vim.env.XDG_CONFIG_HOME = opts.config_dir
  vim.notify = function(msg)
    E.notifications = E.notifications or {}
    table.insert(E.notifications, tostring(msg))
  end
  E.notifications = {}

  require("dbridge").setup({ server_cmd = opts.server_cmd })
  client = require("dbridge.client")

  if opts.ui then
    vim.cmd("Dbridge")
  else
    assert(client.start(opts.server_cmd) ~= false, "server failed to start")
  end
  return true
end

function E.shutdown()
  pcall(vim.cmd, "DbridgeClose")
  if client and client.is_running() then client.stop() end
  return true
end

function E.request(method, params, timeout)
  local r, err = client.request_sync(method, params, timeout or 20000)
  -- nil is not representable across RPC inside a table; normalize to false
  return { result = r, err = err or false }
end

function E.connect_memory()
  local r = E.request("dbridge/connect", { adapter = "sqlite", config = { uri = ":memory:" } }, 30000)
  assert(r.result, "connect failed: " .. vim.inspect(r.err))
  return r.result.session_id
end

function E.exec(sid, sql)
  local r = E.request("dbridge/execute", { session_id = sid, sql = sql })
  assert(r.result, "execute failed: " .. sql .. " -> " .. vim.inspect(r.err))
  return r.result
end

function E.exec_many(sid, sqls)
  for _, sql in ipairs(sqls) do E.exec(sid, sql) end
  return true
end

function E.wait_for(fn, timeout)
  return vim.wait(timeout or 5000, fn, 25)
end

function E.settle(ms)
  vim.wait(ms or 300, function() return false end, 25)
  return true
end

function E.take_notifications()
  local n = E.notifications or {}
  E.notifications = {}
  return n
end

--- Async profiles.* call, driven to completion.
function E.profile_call(name, ...)
  local profiles = require("dbridge.profiles")
  local args = { ... }
  local result, err, done = nil, nil, false
  table.insert(args, function(r, e) result, err, done = r, e, true end)
  profiles[name](unpack(args))
  vim.wait(15000, function() return done end, 25)
  return { result = result, err = err or false, done = done }
end

--- Render a query result into the results panel and return the buffer lines.
function E.render(sid, sql)
  local results = require("dbridge.results")
  local q = E.exec(sid, sql)
  E.notifications = {}
  results.render(q)
  return {
    columns = q.columns,
    warnings = q.warnings,
    lines = vim.api.nvim_buf_get_lines(results.panel.bufnr, 0, -1, false),
    statusline = vim.api.nvim_get_option_value("statusline", { win = results.panel.winid }),
    notifications = E.notifications,
  }
end

function E.results_page(dir)
  local results = require("dbridge.results")
  if dir == "next" then results.next_page() else results.prev_page() end
  return vim.api.nvim_get_option_value("statusline", { win = results.panel.winid })
end

--- Complete at a cursor position in the editor panel.
function E.complete_at(lines, row, col)
  local editor = require("dbridge.editor")
  vim.api.nvim_set_current_win(editor.panel.winid)
  vim.api.nvim_buf_set_lines(editor.panel.bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(editor.panel.winid, { row, col })

  local source = E.source or require("dbridge.cmp"):new()
  E.source = source
  local got, done = nil, false
  source:complete({}, function(res) got = res; done = true end)
  vim.wait(15000, function() return done end, 25)

  local labels, kinds, first = {}, {}, nil
  for i, item in ipairs((got or {}).items or {}) do
    table.insert(labels, item.label)
    kinds[tostring(item.kind)] = true
    if i == 1 then first = item end
  end
  return { labels = labels, kinds = kinds, first = first, done = done }
end

function E.stub_active_session(sid)
  require("dbridge.explorer").get_active_session = function() return sid end
  return true
end

return E
