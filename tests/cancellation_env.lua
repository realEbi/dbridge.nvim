-- Deterministic child-side transport and UI controls. No real server is started.
local F = { sent = {}, jobs = {}, notifications = {}, rendered = {} }

function F.flush()
  local done = false
  vim.schedule(function() done = true end)
  assert(vim.wait(1000, function() return done end, 5), "scheduled UI work did not finish")
end

function F.boot(ui)
  vim.notify = function(message, level)
    table.insert(F.notifications, { message = message, level = level })
  end
  vim.fn.executable = function() return 1 end
  vim.fn.jobstart = function(_, callbacks)
    local job_id = #F.jobs + 1
    F.jobs[job_id] = callbacks
    return job_id
  end
  vim.fn.jobstop = function() return 1 end
  vim.fn.chansend = function(job_id, frame)
    local header, body = frame:match("^(.-)\r\n\r\n(.*)$")
    assert(tonumber(header:match("Content%-Length: (%d+)")) == #body)
    table.insert(F.sent, { job = job_id, body = body, message = vim.json.decode(body) })
    return #frame
  end
  F.client = require("dbridge.client")
  if ui then
    require("dbridge").setup({ server_cmd = { "fake-server" } })
    vim.cmd("Dbridge")
    local explorer = require("dbridge.explorer")
    F.session = "first-session"
    explorer.get_active_session = function() return F.session end
    explorer.get_active_target = function()
      return { session_id = F.session, name = "test", adapter = "sqlite", dialect = "sqlite", path = { "main" } }
    end
    require("dbridge.results").render = function(result) table.insert(F.rendered, result) end
  else
    F.client.start({ "fake-server" })
  end
  F.flush()
  return true
end

function F.reply(id, result, err, job)
  job = job or #F.jobs
  local response = { jsonrpc = "2.0", id = id, result = result, error = err }
  local body = vim.json.encode(response)
  F.jobs[job].on_stdout(job, { "Content-Length: " .. #body .. "\r\n\r\n" .. body })
  F.flush()
end

function F.submit(sql)
  local editor = require("dbridge.editor")
  vim.api.nvim_set_current_win(editor.panel.winid)
  vim.api.nvim_buf_set_lines(editor.panel.bufnr, 0, -1, false, { sql })
  vim.api.nvim_win_set_cursor(editor.panel.winid, { 1, 0 })
  vim.cmd("DbridgeExecuteStatement")
  return F.sent[#F.sent].message.id
end

function F.cancels()
  local ids = {}
  for _, sent in ipairs(F.sent) do
    if sent.message.method == "$/cancelRequest" then table.insert(ids, sent.message.params.id) end
  end
  return ids
end

function F.exit(job, code)
  F.jobs[job].on_exit(job, code or 0)
  F.flush()
end

return F
