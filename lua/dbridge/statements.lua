-- Lexical statement selection for the supported SQLite/DuckDB editor workflow.
-- Offsets count bytes, as do Neovim cursor columns. This is not a SQL validator.
local M = {}

local function trigger_header(head)
  local first = 1
  if head[1] == "EXPLAIN" then
    first = head[2] == "QUERY" and head[3] == "PLAN" and 4 or 2
  end
  return head[first] == "CREATE" and (head[first + 1] == "TRIGGER"
    or ((head[first + 1] == "TEMP" or head[first + 1] == "TEMPORARY")
      and head[first + 2] == "TRIGGER"))
end

local function quoted_end(sql, start, quote, backslashes)
  local close = quote == "[" and "]" or quote
  local i = start + 1
  while i <= #sql do
    local char = sql:sub(i, i)
    if backslashes and char == "\\" then
      i = i + 2
    elseif char == close then
      if quote ~= "[" and sql:sub(i + 1, i + 1) == close then
        i = i + 2
      else
        return i + 1
      end
    else
      i = i + 1
    end
  end
end

local function block_comment_end(sql, start, nested)
  local depth, i = 1, start + 2
  while i <= #sql do
    local pair = sql:sub(i, i + 1)
    if nested and pair == "/*" then
      depth, i = depth + 1, i + 2
    elseif pair == "*/" then
      depth, i = depth - 1, i + 2
      if depth == 0 then return i end
    else
      i = i + 1
    end
  end
end

--- Return the statement at a zero-based byte offset, or nil and a diagnostic.
function M.at(sql, offset, adapter)
  local cursor = math.max(0, math.min(offset, #sql)) + 1
  local start, i, executable = 1, 1, false
  local head, trigger, body = {}, false, false
  local after_on, pending_begin, statement_start, trigger_end = false, false, false, false
  local cases = 0
  local problem

  local function selected(finish)
    if problem then return nil, problem end
    if trigger and not trigger_end then
      return nil, "Unterminated trigger body; finish BEGIN/END before executing"
    end
    if not executable then return nil, "No SQL statement at the cursor" end
    return (sql:sub(start, finish):gsub("^%s+", ""):gsub("%s+$", ""))
  end

  while i <= #sql do
    local char, pair = sql:sub(i, i), sql:sub(i, i + 1)
    if char:match("%s") then
      i = i + 1
    elseif pair == "--" then
      i = sql:find("\n", i + 2, true) or (#sql + 1)
    elseif pair == "/*" then
      local after = block_comment_end(sql, i, adapter ~= "sqlite")
      if not after then
        problem = "Unterminated SQL block comment; close it before executing"
        break
      end
      i = after
    elseif char == "'" or char == '"' or char == "`" or (char == "[" and adapter ~= "duckdb") then
      executable = true
      pending_begin, statement_start = false, false
      local escaped = char == "'" and sql:sub(i - 1, i - 1):lower() == "e"
        and (i < 3 or not sql:sub(i - 2, i - 2):match("[%w_]"))
      local after = quoted_end(sql, i, char, escaped)
      if not after then
        problem = "Unterminated SQL quote; close it before executing"
        break
      end
      i = after
    elseif char == "$" and (i == 1 or not sql:sub(i - 1, i - 1):match("[%w_$]")) then
      local delimiter = sql:sub(i):match("^%$[%a_][%w_]*%$")
        or (pair == "$$" and "$$" or nil)
      executable = true
      pending_begin, statement_start = false, false
      if delimiter then
        local closing = sql:find(delimiter, i + #delimiter, true)
        if not closing then
          problem = "Unterminated dollar-quoted SQL string; close it before executing"
          break
        end
        i = closing + #delimiter
      else
        i = i + 1
      end
    elseif char:match("[%a_]") then
      local word = sql:sub(i):match("^[%w_]+")
      executable = true
      -- Keep EXPLAIN wrappers with a trigger too: splitting its body could turn
      -- an inspection-only request into a separately executed mutation.
      if #head < 6 then table.insert(head, word:upper()) end
      trigger = trigger_header(head)
      if trigger then
        local keyword = word:upper()
        if not body then
          -- BEGIN is also a legal SQLite identifier. The body opener follows
          -- ON's table and precedes a trigger command, unlike a name or column.
          if pending_begin and ({ INSERT = true, UPDATE = true, DELETE = true,
            SELECT = true, REPLACE = true, WITH = true, END = true })[keyword] then
            body, statement_start = true, true
          end
          if keyword == "ON" then after_on = true end
          pending_begin = after_on and keyword == "BEGIN"
        end
        if body then
          if keyword == "CASE" then
            cases = cases + 1
          elseif keyword == "END" then
            if cases > 0 then cases = cases - 1
            elseif statement_start then trigger_end = true end
          end
          statement_start = false
        end
      end
      i = i + #word
    elseif char == ";" then
      if not trigger or trigger_end then
        if cursor <= i then return selected(i) end
        start, executable = i + 1, false
        head, trigger, body = {}, false, false
        after_on, pending_begin, trigger_end, cases = false, false, false, 0
      end
      statement_start = body
      i = i + 1
    else
      executable = true
      pending_begin, statement_start = false, false
      i = i + 1
    end
  end
  return selected(#sql)
end

return M
