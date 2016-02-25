open OusSig
open OusTypes
open OusMisc

let name = "vim"

let check () =
  has_command "vim" &&
  List.exists Re.(execp @@ compile @@ str "+syntax")
    (lines_of_command "vim --version")

(*
 * Base template
 *)

(* vim-sensible @ b30dcf387af977acfa21732592bfca05598b2188 *)
let base_template = [ ".vimrc", lines_of_string
{vim|
" sensible.vim - Defaults everyone can agree on
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.1

if &compatible
  finish
else
  let g:loaded_sensible = 1
endif

if has('autocmd')
  filetype plugin indent on
endif
if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

" Use :help 'option' to see the documentation for the given option.

set autoindent
set backspace=indent,eol,start
set complete-=i
set smarttab

set nrformats-=octal

set ttimeout
set ttimeoutlen=100

set incsearch
" Use <C-L> to clear the highlighting of :set hlsearch.
if maparg('<C-L>', 'n') ==# ''
  nnoremap <silent> <C-L> :nohlsearch<CR><C-L>
endif

set laststatus=2
set ruler
set showcmd
set wildmenu

if !&scrolloff
  set scrolloff=1
endif
if !&sidescrolloff
  set sidescrolloff=5
endif
set display+=lastline

if &encoding ==# 'latin1' && has('gui_running')
  set encoding=utf-8
endif

if &listchars ==# 'eol:$'
  set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
endif

if v:version > 703 || v:version == 703 && has("patch541")
  set formatoptions+=j " Delete comment character when joining commented lines
endif

if has('path_extra')
  setglobal tags-=./tags tags^=./tags;
endif

if &shell =~# 'fish$'
  set shell=/bin/bash
endif

set autoread
set fileformats+=mac

if &history < 1000
  set history=1000
endif
if &tabpagemax < 50
  set tabpagemax=50
endif
if !empty(&viminfo)
  set viminfo^=!
endif
set sessionoptions-=options

" Allow color schemes to do bright colors without forcing bold.
if &t_Co == 8 && $TERM !~# '^linux'
  set t_Co=16
endif

" Load matchit.vim, but only if the user hasn't installed a newer version.
if !exists('g:loaded_matchit') && findfile('plugin/matchit.vim', &rtp) ==# ''
  runtime! macros/matchit.vim
endif

inoremap <C-U> <C-G>u<C-U>
|vim} ]

(*
 * Generic OPAM config
 *)

let base_setup = [ ".vimrc", Text (lines_of_string
{vim|
let s:opam_share_dir = system("opam config var share")
let s:opam_share_dir = substitute(s:opam_share_dir, '[\r\n]*$', '', '')

let s:opam_configuration = {}

function! OpamConfOcpIndent()
  execute "set rtp^=" . s:opam_share_dir . "/ocp-indent/vim"
endfunction
let s:opam_configuration['ocp-indent'] = function('OpamConfOcpIndent')

function! OpamConfOcpIndex()
  execute "set rtp+=" . s:opam_share_dir . "/ocp-index/vim"
endfunction
let s:opam_configuration['ocp-index'] = function('OpamConfOcpIndex')

function! OpamConfMerlin()
  let l:dir = s:opam_share_dir . "/merlin/vim"
  execute "set rtp+=" . l:dir
endfunction
let s:opam_configuration['merlin'] = function('OpamConfMerlin')

let s:opam_packages = ["ocp-indent", "ocp-index", "merlin"]
let s:opam_check_cmdline = "opam list --installed --short --safe --color=never " + join(s:opam_packages, " ")
" was systemlist used here
let s:opam_available_tools = split(system(s:opam_check_cmdline))
for tool in s:opam_packages
  " Respect package order (merlin should be after ocp-index)
  if count(s:opam_available_tools, tool) > 0
    call s:opam_configuration[tool]()
  endif
endfor
|vim}) ]

let files = []

let comment = (^) "\" "

let share_dir = opam_var "share"

module OcpIndent = struct
  (* Fallback for when running in a switch other than where it was installed *)
  let name = "ocp-indent"
  let chunks =
    let contents =
      Printf.sprintf {vim|
if count(s:opam_available_tools,"ocp-indent") == 0
  source %S
endif
|vim}
        (share_dir/"vim"/"syntax"/"ocp-indent.vim")
    in
    [".vimrc", Text (lines_of_string contents)]
  let files = []
  let post_install = []
  let pre_remove = []
end

module OcpIndex = struct
  (* Handled dynamically, invalid in other switches *)
  let name = "ocp-index"
  let chunks = []
  let files = []
  let post_install = []
  let pre_remove = []
end

module Merlin = struct
  (* Handled dynamically, invalid in other switches *)
  let name = "ocp-index"
  let chunks = []
  let files = []
  let post_install = []
  let pre_remove = []
end

let tools = [
  (module OcpIndent : ToolConfig);
  (module OcpIndex : ToolConfig);
  (module Merlin : ToolConfig);
]
