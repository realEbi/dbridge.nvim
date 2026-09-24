local eq = MiniTest.expect.equality
local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({ hooks = {
  pre_case = function()
    child.restart({ "-u", "scripts/child_init.lua" })
    child.lua("F = require('tests.cancellation_env')")
  end,
  post_case = function() child.stop() end,
} })

T["transport returns ids and frames notifications without ids"] = function()
  child.lua([[
    F.boot(false)
    request_id = F.client.request('dbridge/listProfiles', {}, function() end)
    assert(type(request_id) == 'number')
    assert(F.sent[1].message.id == request_id)
    assert(F.sent[1].body:find('"params"%s*:%s*{}'))
    assert(F.client.notify('notice', { text = 'café 🌍' }))
    assert(F.sent[2].message.id == nil)
    assert(F.sent[2].message.params.text == 'café 🌍')
    assert(F.client.notify('notice', {}))
    assert(F.sent[3].body:find('"params"%s*:%s*{}'))
  ]])
end

T["cancellation retains callback and correlates overtaking replies"] = function()
  child.lua([[
    F.boot(false)
    replies = {}
    first = F.client.request('slow', {}, function(result, err) table.insert(replies, { 'first', result, err }) end)
    second = F.client.request('fast', {}, function(result) table.insert(replies, { 'second', result }) end)
    assert(F.client.cancel(first))
    assert(F.sent[3].message.id == nil)
    assert(F.sent[3].message.params.id == first)
    F.reply(second, { value = 2 })
    F.reply(first, nil, { code = -32004, message = 'cancelled' })
    assert(not F.client.cancel(first))
    assert(not F.client.cancel(second))
  ]])
  eq(child.lua_get("replies[1][1]"), "second")
  eq(child.lua_get("replies[1][2].value"), 2)
  eq(child.lua_get("replies[2][1]"), "first")
  eq(child.lua_get("replies[2][3].code"), -32004)
end

T["stop drops old targets and late exit preserves replacement process"] = function()
  child.lua([[
    F.boot(false)
    old = F.client.request('slow', {}, function() error('stale callback') end)
    F.client.stop()
    assert(not F.client.cancel(old))
    local stopped_error
    assert(F.client.request('stopped', {}, function(_, err) stopped_error = err end) == nil)
    assert(stopped_error.message == 'server not running')
    assert(not F.client.notify('notice', {}))
    F.client.start({ 'fake-server' })
    current = F.client.request('new', {}, function(result) new_result = result end)
    F.exit(1)
    assert(F.client.is_running())
    assert(F.client.cancel(current))
    F.jobs[1].on_stdout(1, { 'Content-Length: 1000\r\n\r\nstale' })
    F.reply(current, { ok = true })
  ]])
  eq(child.lua_get("new_result"), { ok = true })
end

T["natural exit drops pending callbacks"] = function()
  child.lua([[
    F.boot(false)
    id = F.client.request('slow', {}, function() error('stale callback') end)
    F.exit(1)
    assert(not F.client.is_running())
    assert(not F.client.cancel(id))
  ]])
end

T["command targets latest pending query despite active Session change"] = function()
  child.lua([[
    F.boot(true)
    first = F.submit('SELECT 1')
    second = F.submit('SELECT 2')
    F.session = 'another-session'
    vim.cmd('DbridgeCancel')
  ]])
  eq(child.lua_get("F.cancels()"), { child.lua_get("second") })
  child.lua([[
    F.reply(second, { rows = { { 2 } } })
    vim.cmd('DbridgeCancel')
  ]])
  eq(child.lua_get("F.cancels()"), { child.lua_get("second"), child.lua_get("first") })
end

T["confirmed cancellation is informational and preserves results"] = function()
  child.lua([[
    F.boot(true)
    baseline = F.submit('SELECT 10')
    F.reply(baseline, { rows = { { 10 } } })
    id = F.submit('SELECT 20')
    vim.cmd('DbridgeCancel')
    assert(F.notifications[#F.notifications].message == '[dbridge] cancellation requested')
    F.reply(id, nil, { code = -32004, message = 'cancelled' })
  ]])
  eq(child.lua_get("F.rendered"), { { rows = { { 10 } } } })
  eq(child.lua_get("F.notifications[#F.notifications]"), {
    message = "[dbridge] query cancelled", level = child.lua_get("vim.log.levels.INFO"),
  })
  child.lua("vim.cmd('DbridgeCancel')")
  eq(child.lua_get("#F.cancels()"), 1)
  eq(child.lua_get("F.notifications[#F.notifications].message"), "[dbridge] no outstanding query")
end

T["normal results after cancellation requests still render and other errors remain errors"] = function()
  child.lua([[
    F.boot(true)
    id = F.submit('SELECT 1')
    vim.cmd('DbridgeCancel')
    F.reply(id, { rows = { { 1 } } })
    failed = F.submit('SELECT missing')
    F.reply(failed, nil, { code = -32001, message = 'missing column' })
  ]])
  eq(child.lua_get("F.rendered"), { { rows = { { 1 } } } })
  eq(child.lua_get("F.notifications[#F.notifications]"), {
    message = "[dbridge] execute error: missing column", level = child.lua_get("vim.log.levels.ERROR"),
  })
  eq(child.lua_get("#F.notifications"), 2)
end

T["stopped UI query is forgotten after restart"] = function()
  child.lua([[
    F.boot(true)
    F.submit('SELECT 1')
    F.client.stop()
    F.flush()
    F.client.start({ 'fake-server' })
    F.flush()
    vim.cmd('DbridgeCancel')
  ]])
  eq(child.lua_get("F.cancels()"), {})
  eq(child.lua_get("F.notifications[#F.notifications].message"), "[dbridge] no outstanding query")
end

T["queued stop event preserves a query submitted immediately after restart"] = function()
  child.lua([[
    F.boot(true)
    old = F.submit('SELECT 1')
    F.client.stop()
    F.client.start({ 'fake-server' })
    current = F.submit('SELECT 2')
    F.flush()
    vim.cmd('DbridgeCancel')
    assert(not F.client.is_pending(old))
    assert(F.client.is_pending(current))
  ]])
  eq(child.lua_get("F.cancels()"), { child.lua_get("current") })
end

return T
