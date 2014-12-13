open OusSig
open OusTypes
open OusMisc

let name = "vim"

let check () =
  has_command "vim" &&
  List.exists Re.(execp @@ compile @@ str "+syntax")
    (lines_of_command "vim --version")

(* I've honestly no idea about this. Please contribute :) *)
let base_template = [ ".vimrc", lines_of_string {vim|
" Basic default vim config installed by opam user-config "
set nocompatible
filetype plugin indent on
syntax on
set grepprg=grep\ -nH\ $*
colorscheme elflord
set number
set expandtab
set mouse=a
|vim} ]

let base_setup = []

let files = []

let comment = (^) "\" "

module OcpIndent = struct
  let name = "ocp-indent"
  let chunks = [".vimrc", Text [
      Printf.sprintf "execute \":source %s/vim/syntax/ocp-indent.vim\""
        (opam_var "share")
    ]]
  let files = []
  let post_install = []
  let pre_remove = []
end

module OcpIndex = struct
  let name = "ocp-index"
  let chunks = [".vimrc", Text [
      Printf.sprintf "execute \":source %s/vim/syntax/ocpindex.vim\""
        (opam_var "share")
    ]]
  let files = []
  let post_install = []
  let pre_remove = []
end

module Merlin = struct
  let name = "merlin"
  let chunks = [".vimrc", Text [
      Printf.sprintf "execute \"set rtp+=%s/merlin/vim\""
        (opam_var "share")
    ]]
  let files = []
  let post_install = [
    fun () ->
      let vim_cmd =
        Printf.sprintf "execute \"helptags %s/merlin/vim/doc\""
          (opam_var "share")
      in
      if 0 <> Sys.command (Printf.sprintf "vim -e \"%s\"" vim_cmd)
      then msg "Warning: post-hook failed for vim/merlin"
  ]
  let pre_remove = [ (* fixme: opposite of the above ? *) ]
end

let tools = [
  (module OcpIndent : ToolConfig);
  (module OcpIndex : ToolConfig);
  (module Merlin : ToolConfig);
]
