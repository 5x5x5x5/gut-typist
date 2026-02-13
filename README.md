# gut-typist

A Neovim plugin for touch typing practice using books from [Project Gutenberg](https://www.gutenberg.org/).

Search for any book, and gut-typist opens a split-pane view: the source text on the left with per-character color feedback, and a typing buffer on the right. Real-time WPM, accuracy, and progress are displayed in the winbar. Sessions are saved automatically so you can pick up where you left off.

## Requirements

- Neovim 0.10+
- `curl` on PATH

## Installation

### lazy.nvim

```lua
{
  "5x5x5x5/gut-typist",
  cmd = "GutTypist",
  opts = {},
}
```

### Manual

Clone the repo and add it to your runtime path:

```lua
vim.opt.rtp:prepend("~/gut-typist")
require("gut-typist").setup({})
```

## Usage

| Command | Description |
|---|---|
| `:GutTypist search <query>` | Search Project Gutenberg and pick a book |
| `:GutTypist start <book_id>` | Start typing a book by its Gutenberg ID |
| `:GutTypist resume` | Resume the most recent session |
| `:GutTypist stop` | Save progress and close |
| `:GutTypist stats` | Show session and lifetime statistics |
| `:GutTypist library` | Browse previously downloaded books |

### Quick start

```vim
:GutTypist search pride prejudice
```

Select a book from the picker, and start typing. Characters in the source pane turn green when correct, red when wrong. Press `:GutTypist stop` to save and quit, `:GutTypist resume` to continue later.

## Highlights

These highlight groups are defined with `default = true` so you can override them in your colorscheme:

| Group | Default | Purpose |
|---|---|---|
| `GutTypistCorrect` | green, bold | Correctly typed character |
| `GutTypistWrong` | red on dark bg, bold | Mistyped character |
| `GutTypistUntyped` | gray | Not yet reached |
| `GutTypistCursor` | inverse | Next character to type |

## Configuration

All options are optional. Defaults shown below:

```lua
require("gut-typist").setup({
  split_ratio = 0.5,           -- width ratio of source pane
  wrap_width = 80,             -- text wrapping width
  save_interval_ms = 5000,     -- auto-save debounce interval
  wpm_window_seconds = 10,     -- rolling WPM calculation window
})
```

## Data storage

Books and session data are stored under `~/.local/share/nvim/gut-typist/`:

```
books/{id}/text.txt        -- cleaned book text
books/{id}/metadata.json   -- title, author
sessions/{id}.json         -- typing progress
lifetime_stats.json        -- accumulated stats
```

## License

MIT
