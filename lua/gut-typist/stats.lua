local config = require("gut-typist.config")

local M = {}

function M.new()
  return {
    start_time = nil,
    total_chars_typed = 0,
    correct_chars = 0,
    -- Ring buffer for rolling WPM
    samples = {},
    sample_index = 0,
  }
end

function M.reset(state)
  state.start_time = nil
  state.total_chars_typed = 0
  state.correct_chars = 0
  state.samples = {}
  state.sample_index = 0
end

function M.record_keystroke(state, is_correct)
  local now = vim.uv.hrtime() / 1e9 -- seconds

  if not state.start_time then
    state.start_time = now
  end

  state.total_chars_typed = state.total_chars_typed + 1
  if is_correct then
    state.correct_chars = state.correct_chars + 1
  end

  -- Add sample for rolling WPM
  state.sample_index = state.sample_index + 1
  state.samples[state.sample_index] = {
    time = now,
    chars = state.total_chars_typed,
  }
end

function M.update_from_comparison(state, typed_len, correct_count, prev_typed_len)
  local now = vim.uv.hrtime() / 1e9

  if not state.start_time then
    state.start_time = now
  end

  -- Track incremental changes
  if typed_len > prev_typed_len then
    local new_chars = typed_len - prev_typed_len
    state.total_chars_typed = state.total_chars_typed + new_chars
  end

  -- Correct chars is the current snapshot
  state.correct_chars = correct_count

  -- Add rolling sample
  state.sample_index = state.sample_index + 1
  state.samples[state.sample_index] = {
    time = now,
    typed = typed_len,
  }
end

function M.wpm(state)
  if not state.start_time or state.sample_index < 2 then
    return 0
  end

  local now = vim.uv.hrtime() / 1e9
  local window = config.values.wpm_window_seconds

  -- Find the sample closest to `window` seconds ago
  local cutoff = now - window
  local start_sample = nil
  for i = state.sample_index, 1, -1 do
    local s = state.samples[i]
    if s and s.time and s.time <= cutoff then
      start_sample = s
      break
    end
  end

  local current = state.samples[state.sample_index]
  if not current then
    return 0
  end

  if start_sample and start_sample.typed and current.typed then
    local chars = current.typed - start_sample.typed
    local elapsed = current.time - start_sample.time
    if elapsed > 0 then
      return (chars / 5) / (elapsed / 60)
    end
  end

  -- Fallback: overall WPM from start
  local elapsed = now - state.start_time
  if elapsed > 0 and current.typed then
    return (current.typed / 5) / (elapsed / 60)
  end

  return 0
end

function M.accuracy(state)
  if state.total_chars_typed == 0 then
    return 100
  end
  return (state.correct_chars / state.total_chars_typed) * 100
end

return M
