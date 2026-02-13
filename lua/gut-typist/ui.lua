local config = require("gut-typist.config")

local M = {}

M.state = {
  tab = nil,
  source_buf = nil,
  source_win = nil,
  typing_buf = nil,
  typing_win = nil,
  augroup = nil,
}

function M.is_open()
  return M.state.tab ~= nil
    and M.state.typing_win ~= nil
    and vim.api.nvim_win_is_valid(M.state.typing_win)
end

function M.open(source_lines)
  -- Open a new tab
  vim.cmd("tabnew")
  M.state.tab = vim.api.nvim_get_current_tabpage()

  -- Create source buffer (left, read-only)
  M.state.source_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.state.source_buf, 0, -1, false, source_lines)
  vim.bo[M.state.source_buf].modifiable = false
  vim.bo[M.state.source_buf].buftype = "nofile"
  vim.bo[M.state.source_buf].bufhidden = "wipe"
  vim.bo[M.state.source_buf].filetype = "gut-typist-source"

  -- Create typing buffer (right, editable)
  M.state.typing_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[M.state.typing_buf].buftype = "nofile"
  vim.bo[M.state.typing_buf].bufhidden = "wipe"
  vim.bo[M.state.typing_buf].filetype = "gut-typist-typing"

  -- Set up the split: source on left
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, M.state.source_buf)
  M.state.source_win = win

  -- Calculate split width
  local total_width = vim.api.nvim_win_get_width(win)
  local source_width = math.floor(total_width * config.values.split_ratio)

  -- Vertical split for typing pane on right
  vim.cmd("vsplit")
  M.state.typing_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.state.typing_win, M.state.typing_buf)

  -- Set source pane width
  vim.api.nvim_win_set_width(M.state.source_win, source_width)

  -- Configure source window
  M._configure_win(M.state.source_win, {
    number = false,
    relativenumber = false,
    wrap = true,
    linebreak = true,
    scrolloff = 5,
    cursorline = false,
    signcolumn = "no",
    foldcolumn = "0",
    statusline = "\\ SOURCE",
  })

  -- Configure typing window
  M._configure_win(M.state.typing_win, {
    number = false,
    relativenumber = false,
    wrap = true,
    linebreak = true,
    scrolloff = 5,
    cursorline = false,
    signcolumn = "no",
    foldcolumn = "0",
  })

  -- Focus the typing pane
  vim.api.nvim_set_current_win(M.state.typing_win)

  -- Set up autocmd to redirect focus back to typing pane
  M.state.augroup = vim.api.nvim_create_augroup("GutTypistUI", { clear = true })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = M.state.augroup,
    callback = function()
      if not M.is_open() then
        return true -- delete autocmd
      end
      local cur_win = vim.api.nvim_get_current_win()
      if cur_win == M.state.source_win and vim.api.nvim_win_is_valid(M.state.typing_win) then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(M.state.typing_win) then
            vim.api.nvim_set_current_win(M.state.typing_win)
          end
        end)
      end
    end,
  })

  -- Initial winbar
  M.update_stats_display(0, 100, 0)
end

function M._configure_win(win, opts)
  for k, v in pairs(opts) do
    vim.api.nvim_set_option_value(k, v, { win = win })
  end
end

function M.update_stats_display(wpm, accuracy, progress)
  if not M.state.typing_win or not vim.api.nvim_win_is_valid(M.state.typing_win) then
    return
  end
  local text = string.format(
    " WPM: %.0f  |  Accuracy: %.1f%%  |  Progress: %.1f%%",
    wpm,
    accuracy,
    progress
  )
  -- Escape for statusline syntax: spaces -> "\ ", percent -> "%%"
  local bar = text:gsub("%%", "%%%%"):gsub(" ", "\\ ")
  vim.api.nvim_set_option_value("winbar", bar, { win = M.state.typing_win })
end

function M.sync_source_scroll(line_0indexed)
  if not M.state.source_win or not vim.api.nvim_win_is_valid(M.state.source_win) then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(M.state.source_buf)
  local target = math.min(line_0indexed + 1, line_count) -- 1-indexed
  vim.api.nvim_win_set_cursor(M.state.source_win, { target, 0 })
end

function M.close()
  -- Remove autocmds
  if M.state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, M.state.augroup)
    M.state.augroup = nil
  end

  -- Close windows (closing the tab is enough if both windows are in the tab)
  local wins = { M.state.typing_win, M.state.source_win }
  for _, w in ipairs(wins) do
    if w and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end

  -- Wipe buffers
  local bufs = { M.state.typing_buf, M.state.source_buf }
  for _, b in ipairs(bufs) do
    if b and vim.api.nvim_buf_is_valid(b) then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end

  M.state = {
    tab = nil,
    source_buf = nil,
    source_win = nil,
    typing_buf = nil,
    typing_win = nil,
    augroup = nil,
  }
end

-- Floating window picker utility

function M.open_picker(title, items, format_fn, on_select)
  local lines = {}
  for i, item in ipairs(items) do
    lines[i] = format_fn(item, i)
  end

  local width = 60
  for _, line in ipairs(lines) do
    width = math.max(width, #line + 4)
  end
  width = math.min(width, math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.6))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  local function close_picker()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function select()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local idx = cursor[1]
    close_picker()
    if idx >= 1 and idx <= #items then
      on_select(items[idx], idx)
    end
  end

  local map_opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", select, map_opts)
  vim.keymap.set("n", "q", close_picker, map_opts)
  vim.keymap.set("n", "<Esc>", close_picker, map_opts)
end

return M
