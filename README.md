# gutenberg-typist

A Vim plugin for touch typing practice using books from [Project Gutenberg](https://www.gutenberg.org/).

Search for any book, and gutenberg-typist opens a split-pane view: the source text on the left with per-character color feedback, and a typing buffer on the right. Real-time WPM, accuracy, and progress are displayed in the statusline. Sessions are saved automatically so you can pick up where you left off.

## Requirements

- Vim 8.2+
- `curl` on PATH

## Installation

### Native Vim 8 packages (no plugin manager)

Works on a fresh Vim install — no extra tools required. Run from any directory:

```sh
mkdir -p ~/.vim/pack/plugins/start
git clone https://github.com/5x5x5x5/gutenberg-typist \
  ~/.vim/pack/plugins/start/gutenberg-typist
```

Restart Vim, then try it:

```vim
:GutTypist search pride prejudice
```

### vim-plug

```vim
Plug '5x5x5x5/gutenberg-typist'
```

Then run `:PlugInstall`.

### Manual (custom location)

Clone the repo anywhere and add it to your runtime path in `~/.vimrc`:

```vim
set rtp+=~/code/gutenberg-typist
```

No `Setup()` call is needed — the plugin loads itself. Only call
`gut_typist#Setup({...})` if you want to override defaults (see Configuration).

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

These highlight groups are defined with `highlight default` so you can override them in your colorscheme:

| Group | Default | Purpose |
|---|---|---|
| `GutTypistCorrect` | green, bold | Correctly typed character |
| `GutTypistWrong` | red on dark bg, bold | Mistyped character |
| `GutTypistUntyped` | gray | Not yet reached |
| `GutTypistCursor` | inverse | Next character to type |

## Configuration

All options are optional. Defaults shown below:

```vim
call gut_typist#Setup({
      \ 'split_ratio': 0.5,
      \ 'wrap_width': 80,
      \ 'save_interval_ms': 5000,
      \ 'wpm_window_seconds': 10,
      \})
```

## Data storage

Books and session data are stored under `~/.vim/gutenberg-typist/`:

```
books/{id}/text.txt        -- cleaned book text
books/{id}/metadata.json   -- title, author
sessions/{id}.json         -- typing progress
lifetime_stats.json        -- accumulated stats
```

## License

MIT
