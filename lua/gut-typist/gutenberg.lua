local config = require("gut-typist.config")
local storage = require("gut-typist.storage")

local M = {}

local function http_get(url, callback)
  vim.system({ "curl", "-sL", "--max-time", "30", url }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, "curl failed (exit " .. result.code .. "): " .. (result.stderr or ""))
        return
      end
      callback(result.stdout, nil)
    end)
  end)
end

function M.search(query, opts, callback)
  if type(opts) == "function" then
    callback = opts
    opts = {}
  end
  opts = opts or {}
  local params = {
    "search=" .. vim.uri_encode(query),
    "languages=en",
    "mime_type=text%2Fplain",
  }
  if opts.page then
    params[#params + 1] = "page=" .. opts.page
  end
  local url = config.values.gutenberg.search_url .. "?" .. table.concat(params, "&")

  http_get(url, function(body, err)
    if err then
      callback(nil, err)
      return
    end
    local ok, data = pcall(vim.json.decode, body)
    if not ok then
      callback(nil, "Failed to parse search results")
      return
    end
    local results = {}
    for _, book in ipairs(data.results or {}) do
      local authors = {}
      for _, a in ipairs(book.authors or {}) do
        authors[#authors + 1] = a.name
      end
      results[#results + 1] = {
        id = book.id,
        title = book.title or "Untitled",
        authors = authors,
        author = table.concat(authors, ", "),
        download_count = book.download_count or 0,
      }
    end
    callback(results, nil)
  end)
end

local function strip_gutenberg_header_footer(text)
  -- Strip header: everything up to and including "*** START OF..." line
  local start_marker = text:find("%*%*%* START OF TH[IE]S? PROJECT GUTENBERG")
  if start_marker then
    local line_end = text:find("\n", start_marker)
    if line_end then
      text = text:sub(line_end + 1)
    end
  end

  -- Strip footer: everything from "*** END OF..." line onward
  local end_marker = text:find("%*%*%* END OF TH[IE]S? PROJECT GUTENBERG")
  if end_marker then
    text = text:sub(1, end_marker - 1)
  end

  -- Trim leading/trailing whitespace
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  return text
end

function M.download(book_id, callback)
  -- Check cache first
  local cached = storage.load_book_text(book_id)
  if cached then
    callback(cached, nil)
    return
  end

  local url = string.format(config.values.gutenberg.book_url, book_id, book_id)

  http_get(url, function(body, err)
    if err then
      callback(nil, err)
      return
    end
    if not body or #body == 0 then
      callback(nil, "Empty response from Gutenberg")
      return
    end

    local cleaned = strip_gutenberg_header_footer(body)

    -- Normalize line endings
    cleaned = cleaned:gsub("\r\n", "\n"):gsub("\r", "\n")

    -- Cache locally
    storage.save_book_text(book_id, cleaned)

    callback(cleaned, nil)
  end)
end

function M.download_with_metadata(book_id, metadata, callback)
  if metadata then
    storage.save_book_metadata(book_id, metadata)
  end
  M.download(book_id, callback)
end

function M.list_cached()
  return storage.list_cached_books()
end

return M
