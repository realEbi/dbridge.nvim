-- stdio JSON-RPC 2.0 client with LSP framing
-- Spawns `dbridge.server` as a child process and communicates over stdin/stdout.
local M = {}

local _job_id = nil
local _next_id = 1
local _pending = {} -- id → callback(result, err)
local _buf = ""    -- raw receive buffer for partial chunks

local function state_changed()
  local running = _job_id ~= nil
  vim.schedule(function()
    if M.on_state_changed then M.on_state_changed(running) end
  end)
end

local function send(msg)
  local body = vim.fn.json_encode(msg)
  local frame = "Content-Length: " .. #body .. "\r\n\r\n" .. body
  vim.fn.chansend(_job_id, frame)
end

local function dispatch_response(msg)
  local id = msg.id
  if not id then return end
  local cb = _pending[id]
  if not cb then return end
  _pending[id] = nil
  if msg.error then
    cb(nil, msg.error)
  else
    cb(msg.result, nil)
  end
end

local function on_stdout(_, data, _)
  _buf = _buf .. table.concat(data, "\n")
  while true do
    -- find header boundary
    local _, hdr_end = _buf:find("\r\n\r\n", 1, true)
    if not hdr_end then break end
    local header = _buf:sub(1, hdr_end)
    local len = tonumber(header:match("Content%-Length: (%d+)"))
    if not len then break end
    local body_start = hdr_end + 1
    local body_end = body_start + len - 1
    if #_buf < body_end then break end
    local body = _buf:sub(body_start, body_end)
    _buf = _buf:sub(body_end + 1)
    local ok, msg = pcall(vim.fn.json_decode, body)
    if ok then dispatch_response(msg) end
  end
end

function M.start(cmd)
  if _job_id then return end

  -- jobstart() throws E475 when argv[1] is not executable, so check first and
  -- report something the user can act on.
  if vim.fn.executable(cmd[1]) ~= 1 then
    vim.notify(
      ("[dbridge] server command %q not found on PATH.\n"):format(cmd[1])
        .. "Install the server (`pip install dbridge`), or point the plugin at it:\n"
        .. '  require("dbridge").setup({ server_cmd = { "uv", "run", "python", "-m", "dbridge.server" } })',
      vim.log.levels.ERROR
    )
    return false
  end

  local ok, job = pcall(vim.fn.jobstart, cmd, {
    on_stdout = on_stdout,
    on_stderr = function(_, data, _)
      local msg = table.concat(data, "")
      if msg ~= "" then vim.notify("[dbridge] " .. msg, vim.log.levels.WARN) end
    end,
    on_exit = function(_, code, _)
      _job_id = nil
      state_changed()
      if code ~= 0 then
        vim.notify("[dbridge] server exited with code " .. code, vim.log.levels.ERROR)
      end
    end,
    stdout_buffered = false,
  })
  if not ok or job <= 0 then
    vim.notify(
      "[dbridge] failed to start server: " .. table.concat(cmd, " ") ..
        (ok and "" or ("\n" .. tostring(job))),
      vim.log.levels.ERROR
    )
    return false
  end
  _job_id = job
  state_changed()
  return true
end

function M.stop()
  if _job_id then
    vim.fn.jobstop(_job_id)
    _job_id = nil
    state_changed()
  end
end

-- Async request: cb(result, err)
function M.request(method, params, cb)
  if not _job_id then
    cb(nil, { message = "server not running" })
    return
  end
  -- Lua cannot tell an empty list from an empty map, and json_encode turns `{}`
  -- into `[]`. DSP params are always an object, and the server rejects an array
  -- outright, so methods taking no params (listProfiles) must send `{}`.
  if params == nil or vim.tbl_isempty(params) then
    params = vim.empty_dict()
  end
  local id = _next_id
  _next_id = _next_id + 1
  _pending[id] = cb
  send({ jsonrpc = "2.0", id = id, method = method, params = params })
end

-- Sync wrapper (blocks via vim.wait)
function M.request_sync(method, params, timeout_ms)
  local result, err
  local done = false
  M.request(method, params, function(r, e)
    result, err, done = r, e, true
  end)
  vim.wait(timeout_ms or 5000, function() return done end, 10)
  return result, err
end

function M.is_running() return _job_id ~= nil end

return M
