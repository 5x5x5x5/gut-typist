local ui = require("gut-typist.ui")
local highlight = require("gut-typist.highlight")
local stats_mod = require("gut-typist.stats")
local storage = require("gut-typist.storage")
local util = require("gut-typist.util")
local config = require("gut-typist.config")

local M = {}

M.state = {
  active = false,
  book_id = nil,
  source_text = nil, -- flat string
  source_lines = nil, -- array of lines
  stats = nil,
  prev_typed_len = 0,
  augroup = nil,
  save_timer = nil,
}

local function get_visible_range(win, buf)
  if not vim.api.nvim_win_is_valid(win) then
    return 0, 0
  end
  local info = vim.fn.getwininfo(win)[1]
  if not info then
    return 0, 0
  end
  local top = info.topline - 1 -- 0-indexed
  local bot = info.botline - 1
  local line_count = vim.api.nvim_buf_line_count(buf)
  bot = math.min(bot, line_count - 1)
  return top, bot
end

local function on_text_changed()
  if not M.state.active or not ui.is_open() then
    return
  end

  -- Read all typed text and flatten
  local typed_lines = vim.api.nvim_buf_get_lines(ui.state.typing_buf, 0, -1, false)
  local typed_text = util.flatten_lines(typed_lines)
  local typed_len = #typed_text

  local source = M.state.source_text
  local source_len = #source

  -- Character-by-character comparison
  local matches = {}
  local correct_count = 0
  local compare_len = math.min(typed_len, source_len)
  for i = 1, compare_len do
    local typed_byte = typed_text:byte(i)
    local source_byte = source:byte(i)
    if typed_byte == source_byte then
      matches[i] = true
      correct_count = correct_count + 1
    else
      matches[i] = false
    end
  end

  -- Update stats
  stats_mod.update_from_comparison(M.state.stats, typed_len, correct_count, M.state.prev_typed_len)
  M.state.prev_typed_len = typed_len

  -- Apply highlights on visible range of source buffer
  local top, bot = get_visible_range(ui.state.source_win, ui.state.source_buf)
  highlight.apply(ui.state.source_buf, M.state.source_lines, typed_len, matches, top, bot)

  -- Calculate and display stats
  local wpm = stats_mod.wpm(M.state.stats)
  local accuracy = stats_mod.accuracy(M.state.stats)
  local progress = 0
  if source_len > 0 then
    progress = (typed_len / source_len) * 100
  end
  ui.update_stats_display(wpm, accuracy, progress)

  -- Sync source scroll to typing position
  local line, _ = util.offset_to_pos(M.state.source_lines, math.min(typed_len, source_len - 1))
  ui.sync_source_scroll(line)
end

function M.start(book_id, source_text, resume_offset)
  if M.state.active then
    M.stop()
  end

  local source_lines = util.split_lines(source_text)
  local flat_source = util.flatten_lines(source_lines)

  M.state = {
    active = true,
    book_id = book_id,
    source_text = flat_source,
    source_lines = source_lines,
    stats = stats_mod.new(),
    prev_typed_len = 0,
    augroup = nil,
    save_timer = nil,
  }

  -- Open UI
  ui.open(source_lines)

  -- Apply initial untyped highlights
  local top, bot = get_visible_range(ui.state.source_win, ui.state.source_buf)
  highlight.apply(ui.state.source_buf, source_lines, 0, {}, top, bot)

  -- If resuming, pre-fill typed text
  if resume_offset and resume_offset > 0 then
    local resume_text = flat_source:sub(1, resume_offset)
    local resume_lines = util.split_lines(resume_text)
    vim.api.nvim_buf_set_lines(ui.state.typing_buf, 0, -1, false, resume_lines)
    -- Move cursor to end
    local last_line = #resume_lines
    if last_line > 0 then
      local last_col = #resume_lines[last_line]
      vim.api.nvim_win_set_cursor(ui.state.typing_win, { last_line, last_col })
    end
  end

  -- Register autocmds
  M.state.augroup = vim.api.nvim_create_augroup("GutTypistEngine", { clear = true })

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    group = M.state.augroup,
    buffer = ui.state.typing_buf,
    callback = on_text_changed,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = M.state.augroup,
    callback = function(ev)
      local closed_win = tonumber(ev.match)
      if closed_win == ui.state.typing_win or closed_win == ui.state.source_win then
        vim.schedule(function()
          M.stop()
        end)
        return true -- delete autocmd
      end
    end,
  })

  -- Also re-highlight on source window scroll
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = M.state.augroup,
    callback = function()
      if not M.state.active or not ui.is_open() then
        return true
      end
      -- Re-apply highlights for new visible range
      local typed_lines = vim.api.nvim_buf_get_lines(ui.state.typing_buf, 0, -1, false)
      local typed_text = util.flatten_lines(typed_lines)
      local typed_len = #typed_text
      local source_len = #M.state.source_text

      local matches = {}
      local compare_len = math.min(typed_len, source_len)
      for i = 1, compare_len do
        if typed_text:byte(i) == M.state.source_text:byte(i) then
          matches[i] = true
        else
          matches[i] = false
        end
      end

      local new_top, new_bot = get_visible_range(ui.state.source_win, ui.state.source_buf)
      highlight.apply(ui.state.source_buf, M.state.source_lines, typed_len, matches, new_top, new_bot)
    end,
  })

  -- Debounced session save
  local debounced_save = util.debounce(function()
    if M.state.active and M.state.book_id then
      M._save_session()
    end
  end, config.values.save_interval_ms)
  M.state.save_timer = debounced_save

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    group = M.state.augroup,
    buffer = ui.state.typing_buf,
    callback = function()
      if M.state.save_timer then
        M.state.save_timer()
      end
    end,
  })

  -- Trigger initial display for resume
  if resume_offset and resume_offset > 0 then
    vim.schedule(on_text_changed)
  end
end

function M._save_session()
  if not M.state.book_id then
    return
  end
  local typed_lines = {}
  if ui.is_open() then
    typed_lines = vim.api.nvim_buf_get_lines(ui.state.typing_buf, 0, -1, false)
  end
  local typed_text = util.flatten_lines(typed_lines)

  storage.save_session(M.state.book_id, {
    book_id = M.state.book_id,
    offset = #typed_text,
    total_chars_typed = M.state.stats.total_chars_typed,
    correct_chars = M.state.stats.correct_chars,
  })
end

function M.stop()
  if not M.state.active then
    return
  end

  -- Save session before cleanup
  M._save_session()

  -- Update lifetime stats
  local lifetime = storage.load_lifetime_stats()
  lifetime.total_chars = lifetime.total_chars + M.state.stats.total_chars_typed
  lifetime.correct_chars = lifetime.correct_chars + M.state.stats.correct_chars
  if M.state.stats.start_time then
    local elapsed = (vim.uv.hrtime() / 1e9) - M.state.stats.start_time
    lifetime.total_time_seconds = lifetime.total_time_seconds + elapsed
  end
  lifetime.sessions_count = lifetime.sessions_count + 1
  storage.save_lifetime_stats(lifetime)

  -- Clear autocmds
  if M.state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, M.state.augroup)
  end

  -- Clean up debounce timer
  if M.state.save_timer and M.state.save_timer.close then
    M.state.save_timer.close()
  end

  -- Clear highlights
  if ui.state.source_buf and vim.api.nvim_buf_is_valid(ui.state.source_buf) then
    highlight.clear(ui.state.source_buf)
  end

  -- Close UI
  ui.close()

  M.state = {
    active = false,
    book_id = nil,
    source_text = nil,
    source_lines = nil,
    stats = nil,
    prev_typed_len = 0,
    augroup = nil,
    save_timer = nil,
  }

  vim.notify("GutTypist: Session saved", vim.log.levels.INFO)
end

function M.is_active()
  return M.state.active
end

return M
