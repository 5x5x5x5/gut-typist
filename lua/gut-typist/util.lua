local M = {}

function M.split_lines(str)
  local lines = {}
  for line in (str .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

function M.wrap_text(text, width)
  width = width or 80
  local lines = M.split_lines(text)
  local result = {}
  for _, line in ipairs(lines) do
    if #line == 0 then
      result[#result + 1] = ""
    elseif #line <= width then
      result[#result + 1] = line
    else
      local pos = 1
      while pos <= #line do
        if pos + width - 1 >= #line then
          result[#result + 1] = line:sub(pos)
          break
        end
        -- Find last space within width
        local chunk = line:sub(pos, pos + width - 1)
        local wrap_at = chunk:match(".*()%s")
        if wrap_at and wrap_at > 1 then
          result[#result + 1] = line:sub(pos, pos + wrap_at - 2)
          pos = pos + wrap_at
        else
          -- No space found, hard break
          result[#result + 1] = chunk
          pos = pos + width
        end
      end
    end
  end
  return result
end

function M.debounce(fn, delay_ms)
  local timer = vim.uv.new_timer()
  local debounced = {}
  debounced.call = function(...)
    local args = { ... }
    timer:stop()
    timer:start(delay_ms, 0, function()
      timer:stop()
      vim.schedule(function()
        fn(unpack(args))
      end)
    end)
  end
  debounced.close = function()
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
  end
  setmetatable(debounced, { __call = function(_, ...) debounced.call(...) end })
  return debounced
end

function M.flatten_lines(lines)
  return table.concat(lines, "\n")
end

-- Convert a linear character offset into (line, col) in an array of lines
-- where lines are joined by \n. Both returned values are 0-indexed.
function M.offset_to_pos(lines, offset)
  local remaining = offset
  for i, line in ipairs(lines) do
    local len = #line + 1 -- +1 for the \n
    if remaining < len then
      return i - 1, remaining
    end
    remaining = remaining - len
  end
  -- Past the end
  local last = #lines
  if last == 0 then
    return 0, 0
  end
  return last - 1, #lines[last]
end

return M
