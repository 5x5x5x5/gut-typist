" gut-typist: Touch typing practice with Project Gutenberg books
" Requires Vim 8.2+

if exists('g:loaded_gut_typist')
  finish
endif
let g:loaded_gut_typist = 1

" Define highlight groups (default = user can override)
function! s:DefineHighlights() abort
  highlight default GutTypistCorrect gui=bold guifg=#50fa7b cterm=bold ctermfg=Green
  highlight default GutTypistWrong gui=bold guifg=#ff5555 guibg=#44475a cterm=bold ctermfg=Red ctermbg=DarkGray
  highlight default GutTypistUntyped guifg=#6272a4 ctermfg=Gray
  highlight default GutTypistCursor gui=bold guifg=#282a36 guibg=#f8f8f2 cterm=bold ctermfg=Black ctermbg=White
endfunction

call s:DefineHighlights()

augroup GutTypistHighlights
  autocmd!
  autocmd ColorScheme * call s:DefineHighlights()
augroup END

command! -nargs=+ -complete=customlist,gut_typist#Complete GutTypist call gut_typist#Command(<f-args>)
