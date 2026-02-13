if vim.g.loaded_gut_typist then
  return
end
vim.g.loaded_gut_typist = true

-- Define highlight groups with default=true so users can override
local function define_highlights()
  vim.api.nvim_set_hl(0, "GutTypistCorrect", { default = true, fg = "#50fa7b", bold = true })
  vim.api.nvim_set_hl(0, "GutTypistWrong", { default = true, fg = "#ff5555", bg = "#44475a", bold = true })
  vim.api.nvim_set_hl(0, "GutTypistUntyped", { default = true, fg = "#6272a4" })
  vim.api.nvim_set_hl(0, "GutTypistCursor", { default = true, bg = "#f8f8f2", fg = "#282a36", bold = true })
end

define_highlights()

-- Re-apply highlights on colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("GutTypistHighlights", { clear = true }),
  callback = define_highlights,
})

-- Register the :GutTypist command
vim.api.nvim_create_user_command("GutTypist", function(opts)
  require("gut-typist").command(opts)
end, {
  nargs = "+",
  complete = function(arg_lead, cmd_line, _)
    local subcmds = { "search", "start", "resume", "stop", "stats", "library" }
    -- If we're still completing the first argument
    local parts = vim.split(cmd_line, "%s+")
    if #parts <= 2 then
      return vim.tbl_filter(function(s)
        return s:find(arg_lead, 1, true) == 1
      end, subcmds)
    end
    return {}
  end,
})
