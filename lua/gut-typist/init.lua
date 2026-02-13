local config = require("gut-typist.config")

local M = {}

function M.setup(opts)
  config.apply(opts)
end

function M.command(opts)
  local args = opts.fargs or {}
  local subcmd = args[1]

  if not subcmd then
    vim.notify("GutTypist: Usage: :GutTypist <search|start|resume|stop|stats|library>", vim.log.levels.WARN)
    return
  end

  if subcmd == "search" then
    local query = table.concat(args, " ", 2)
    if query == "" then
      vim.notify("GutTypist: Usage: :GutTypist search <query>", vim.log.levels.WARN)
      return
    end
    M._search(query)
  elseif subcmd == "start" then
    local book_id = args[2]
    if not book_id then
      vim.notify("GutTypist: Usage: :GutTypist start <book_id>", vim.log.levels.WARN)
      return
    end
    M._start(tonumber(book_id))
  elseif subcmd == "resume" then
    M._resume()
  elseif subcmd == "stop" then
    local engine = require("gut-typist.engine")
    engine.stop()
  elseif subcmd == "stats" then
    M._show_stats()
  elseif subcmd == "library" then
    M._library()
  else
    vim.notify("GutTypist: Unknown command: " .. subcmd, vim.log.levels.ERROR)
  end
end

function M._search(query)
  local gutenberg = require("gut-typist.gutenberg")
  local ui = require("gut-typist.ui")

  vim.notify("GutTypist: Searching for '" .. query .. "'...", vim.log.levels.INFO)

  gutenberg.search(query, function(results, err)
    if err then
      vim.notify("GutTypist: Search failed: " .. err, vim.log.levels.ERROR)
      return
    end
    if not results or #results == 0 then
      vim.notify("GutTypist: No results found", vim.log.levels.WARN)
      return
    end

    ui.open_picker("Search Results", results, function(item, idx)
      return string.format("%d. [%d] %s — %s", idx, item.id, item.title, item.author)
    end, function(item)
      M._start_with_metadata(item.id, {
        id = item.id,
        title = item.title,
        author = item.author,
        authors = item.authors,
      })
    end)
  end)
end

function M._start_with_metadata(book_id, metadata)
  local gutenberg = require("gut-typist.gutenberg")
  local engine = require("gut-typist.engine")
  local storage = require("gut-typist.storage")

  vim.notify("GutTypist: Loading book " .. book_id .. "...", vim.log.levels.INFO)

  gutenberg.download_with_metadata(book_id, metadata, function(text, err)
    if err then
      vim.notify("GutTypist: Download failed: " .. err, vim.log.levels.ERROR)
      return
    end

    -- Check for existing session
    local session = storage.load_session(book_id)
    local offset = 0
    if session and session.offset and session.offset > 0 then
      local answer = vim.fn.confirm(
        "Resume from previous session? (offset: " .. session.offset .. ")",
        "&Yes\n&No\n&Reset",
        1
      )
      if answer == 1 then
        offset = session.offset
      elseif answer == 3 then
        storage.save_session(book_id, { book_id = book_id, offset = 0 })
      end
    end

    engine.start(book_id, text, offset)
  end)
end

function M._start(book_id)
  M._start_with_metadata(book_id, nil)
end

function M._resume()
  local storage = require("gut-typist.storage")
  local session = storage.last_session()
  if not session or not session.book_id then
    vim.notify("GutTypist: No previous session found", vim.log.levels.WARN)
    return
  end
  M._start_with_metadata(session.book_id, nil)
end

function M._show_stats()
  local storage = require("gut-typist.storage")
  local lifetime = storage.load_lifetime_stats()
  local engine = require("gut-typist.engine")

  local lines = { "=== GutTypist Stats ===" }

  -- Current session stats
  if engine.is_active() then
    local stats_mod = require("gut-typist.stats")
    local st = engine.state.stats
    lines[#lines + 1] = ""
    lines[#lines + 1] = "-- Current Session --"
    lines[#lines + 1] = string.format("  WPM:      %.0f", stats_mod.wpm(st))
    lines[#lines + 1] = string.format("  Accuracy: %.1f%%", stats_mod.accuracy(st))
    lines[#lines + 1] = string.format("  Chars:    %d typed, %d correct", st.total_chars_typed, st.correct_chars)
  end

  -- Lifetime stats
  lines[#lines + 1] = ""
  lines[#lines + 1] = "-- Lifetime --"
  lines[#lines + 1] = string.format("  Sessions:  %d", lifetime.sessions_count)
  lines[#lines + 1] = string.format("  Chars:     %d typed, %d correct", lifetime.total_chars, lifetime.correct_chars)
  if lifetime.total_chars > 0 then
    lines[#lines + 1] = string.format(
      "  Accuracy:  %.1f%%",
      (lifetime.correct_chars / lifetime.total_chars) * 100
    )
  end
  if lifetime.total_time_seconds > 0 then
    local mins = lifetime.total_time_seconds / 60
    lines[#lines + 1] = string.format("  Time:      %.0f minutes", mins)
    if lifetime.total_chars > 0 then
      lines[#lines + 1] = string.format(
        "  Avg WPM:   %.0f",
        (lifetime.total_chars / 5) / mins
      )
    end
  end

  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local width = 40
  for _, l in ipairs(lines) do
    width = math.max(width, #l + 4)
  end
  local height = #lines

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
    title = " Stats ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, nowait = true, silent = true })
end

function M._library()
  local gutenberg = require("gut-typist.gutenberg")
  local ui = require("gut-typist.ui")

  local books = gutenberg.list_cached()
  if #books == 0 then
    vim.notify("GutTypist: No cached books. Use :GutTypist search <query> to find books.", vim.log.levels.INFO)
    return
  end

  ui.open_picker("Library", books, function(item, idx)
    local author = item.author or table.concat(item.authors or {}, ", ")
    return string.format("%d. [%s] %s — %s", idx, item.id, item.title or "Untitled", author)
  end, function(item)
    M._start_with_metadata(item.id, item)
  end)
end

return M
