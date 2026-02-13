local M = {}

local base_dir

local function get_base_dir()
  if not base_dir then
    local data = vim.fn.stdpath("data")
    base_dir = data .. "/gut-typist"
  end
  return base_dir
end

local function ensure_dir(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

local function read_json(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  if content == "" then
    return nil
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end
  return data
end

local function write_json(path, data)
  ensure_dir(vim.fn.fnamemodify(path, ":h"))
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    return false
  end
  local f = io.open(path, "w")
  if not f then
    return false
  end
  f:write(encoded)
  f:close()
  return true
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function write_file(path, content)
  ensure_dir(vim.fn.fnamemodify(path, ":h"))
  local f = io.open(path, "w")
  if not f then
    return false
  end
  f:write(content)
  f:close()
  return true
end

-- Book text

function M.book_dir(book_id)
  return get_base_dir() .. "/books/" .. tostring(book_id)
end

function M.save_book_text(book_id, text)
  local path = M.book_dir(book_id) .. "/text.txt"
  return write_file(path, text)
end

function M.load_book_text(book_id)
  local path = M.book_dir(book_id) .. "/text.txt"
  return read_file(path)
end

function M.save_book_metadata(book_id, metadata)
  local path = M.book_dir(book_id) .. "/metadata.json"
  return write_json(path, metadata)
end

function M.load_book_metadata(book_id)
  local path = M.book_dir(book_id) .. "/metadata.json"
  return read_json(path)
end

-- Sessions

function M.session_path(book_id)
  return get_base_dir() .. "/sessions/" .. tostring(book_id) .. ".json"
end

function M.save_session(book_id, session)
  session.last_active = os.time()
  return write_json(M.session_path(book_id), session)
end

function M.load_session(book_id)
  return read_json(M.session_path(book_id))
end

function M.last_session()
  local sessions_dir = get_base_dir() .. "/sessions"
  if vim.fn.isdirectory(sessions_dir) == 0 then
    return nil
  end
  local files = vim.fn.glob(sessions_dir .. "/*.json", false, true)
  if #files == 0 then
    return nil
  end
  local latest = nil
  local latest_time = 0
  for _, file in ipairs(files) do
    local data = read_json(file)
    if data and data.last_active and data.last_active > latest_time then
      latest = data
      latest_time = data.last_active
    end
  end
  return latest
end

-- Lifetime stats

function M.stats_path()
  return get_base_dir() .. "/lifetime_stats.json"
end

function M.load_lifetime_stats()
  return read_json(M.stats_path()) or {
    total_chars = 0,
    correct_chars = 0,
    total_time_seconds = 0,
    sessions_count = 0,
  }
end

function M.save_lifetime_stats(stats)
  return write_json(M.stats_path(), stats)
end

-- List cached books

function M.list_cached_books()
  local books_dir = get_base_dir() .. "/books"
  if vim.fn.isdirectory(books_dir) == 0 then
    return {}
  end
  local dirs = vim.fn.glob(books_dir .. "/*", false, true)
  local books = {}
  for _, dir in ipairs(dirs) do
    local id = vim.fn.fnamemodify(dir, ":t")
    local meta = M.load_book_metadata(id)
    if meta then
      meta.id = id
      books[#books + 1] = meta
    end
  end
  return books
end

return M
