local M = {}

M.defaults = {
  split_ratio = 0.5,
  wrap_width = 80,
  gutenberg = {
    search_url = "https://gutendex.com/books",
    book_url = "https://www.gutenberg.org/cache/epub/%d/pg%d.txt",
  },
  highlights = {
    correct = "GutTypistCorrect",
    wrong = "GutTypistWrong",
    untyped = "GutTypistUntyped",
    cursor = "GutTypistCursor",
  },
  paragraph_mode = false,
  save_interval_ms = 5000,
  wpm_window_seconds = 10,
}

M.values = vim.deepcopy(M.defaults)

function M.apply(opts)
  M.values = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
