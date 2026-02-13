local config = require("gut-typist.config")

local M = {}

local ns = vim.api.nvim_create_namespace("gut_typist")

M.ns = ns

-- Apply per-character extmarks on the source buffer for the visible range.
-- typed_len: how many characters have been typed so far (linear offset)
-- matches: table of booleans indexed 1..typed_len, true = correct
-- source_lines: the full source lines array
-- source_buf: the source buffer handle
-- visible_top: 0-indexed first visible line
-- visible_bot: 0-indexed last visible line
function M.apply(source_buf, source_lines, typed_len, matches, visible_top, visible_bot)
  local hl = config.values.highlights

  -- Clear existing extmarks in visible range
  vim.api.nvim_buf_clear_namespace(source_buf, ns, visible_top, visible_bot + 1)

  -- Calculate character offset for visible_top
  local offset = 0
  for i = 1, visible_top do
    offset = offset + #source_lines[i] + 1 -- +1 for \n
  end

  for line_idx = visible_top, visible_bot do
    local line_num = line_idx + 1 -- 1-indexed into source_lines
    if line_num > #source_lines then
      break
    end
    local line = source_lines[line_num]
    local line_offset = offset

    local col = 0
    while col < #line do
      local char_pos = line_offset + col + 1 -- 1-indexed into matches
      local hl_group
      if char_pos == typed_len + 1 then
        hl_group = hl.cursor
      elseif char_pos <= typed_len then
        if matches[char_pos] then
          hl_group = hl.correct
        else
          hl_group = hl.wrong
        end
      else
        hl_group = hl.untyped
      end

      -- Calculate byte length of this UTF-8 character
      local byte = line:byte(col + 1)
      local char_len = 1
      if byte and byte >= 0xF0 then
        char_len = 4
      elseif byte and byte >= 0xE0 then
        char_len = 3
      elseif byte and byte >= 0xC0 then
        char_len = 2
      end

      vim.api.nvim_buf_set_extmark(source_buf, ns, line_idx, col, {
        end_col = col + char_len,
        hl_group = hl_group,
        priority = 100,
      })
      col = col + char_len
    end

    -- Also highlight the newline position (end of line) if it's the cursor pos
    local newline_pos = line_offset + #line + 1 -- 1-indexed
    if newline_pos == typed_len + 1 and line_idx <= visible_bot then
      -- Mark end of line as cursor via virtual text or eol extmark
      vim.api.nvim_buf_set_extmark(source_buf, ns, line_idx, #line, {
        end_col = #line,
        hl_group = hl.cursor,
        virt_text = { { " ", hl.cursor } },
        virt_text_pos = "inline",
        priority = 100,
      })
    end

    offset = offset + #line + 1 -- +1 for \n
  end
end

function M.clear(source_buf)
  vim.api.nvim_buf_clear_namespace(source_buf, ns, 0, -1)
end

return M
