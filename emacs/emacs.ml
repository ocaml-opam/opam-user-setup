open OusSig
open OusTypes
open OusMisc

let name = "emacs"

let base_template = [".emacs", lines_of_string {elisp|
;; Basic .emacs with a good set of defaults, to be used as template for usage
;; with OCaml, OPAM, and tuareg
;;
;; Requires tuareg or ocaml mode installed on the system
;;
;; Author: Louis Gesbert <louis.gesbert@ocamlpro.com>
;; Released under CC(0)

;; Generic, recommended configuration options

(custom-set-variables
 '(indent-tabs-mode nil)
 '(compilation-context-lines 2)
 '(compilation-error-screen-columns nil)
 '(compilation-scroll-output t)
 '(compilation-search-path (quote (nil "src")))
 '(electric-indent-mode nil)
 '(next-line-add-newlines nil)
 '(require-final-newline t)
 '(sentence-end-double-space nil)
 '(show-trailing-whitespace t)
 '(visible-bell t)
 '(show-paren-mode t)
 '(next-error-highlight t)
 '(next-error-highlight-no-select t)
 '(backup-directory-alist '(("." . "~/.local/share/emacs/backups")))
 '(ac-use-fuzzy nil)
 )

;; ANSI color in compilation buffer
(require 'ansi-color)
(defun colorize-compilation-buffer ()
  (toggle-read-only)
  (ansi-color-apply-on-region (point-min) (point-max))
  (toggle-read-only))
(add-hook 'compilation-filter-hook 'colorize-compilation-buffer)

;; Some key bindings

(global-set-key [f3] 'next-match)
(defun prev-match () (interactive nil) (next-match -1))
(global-set-key [(shift f3)] 'prev-match)
(global-set-key [backtab] 'auto-complete)

;; OCaml configuration
;;  - better error and backtrace matching
(defun set-ocaml-error-regexp ()
  (set
   'compilation-error-regexp-alist
   '("[Ff]ile \\(\"\\(.*?\\)\", line \\(-?[0-9]+\\)\\(, characters \\(-?[0-9]+\\)-\\([0-9]+\\)\\)?\\)\\(:\n\\(\\(Warning .*?\\)\\|\\(Error\\)\\):\\)?"
    2 3 (5 . 6) (9 . 11) 1 (8 compilation-message-face))))

(add-hook 'tuareg-mode-hook 'set-ocaml-error-regexp)
(add-hook 'ocaml-mode-hook 'set-ocaml-error-regexp)
|elisp} ]

let dot_emacs_chunk =
  let def_loadpath =
    let share = match lines_of_command "opam config var share" with
      | [share] -> share
      | _ -> failwith "Bad answer from 'opam config var share"
    in
    Printf.sprintf "(add-to-list 'load-path \"%s/emacs/site-lisp\")" share
  in
  let def_env =
    "(defvar static-opam-env (quote" ::
    lines_of_command "opam config env --sexp" @
    ["))"]
  in
  let base = {elisp|
(defun set-opam-env-locally ()
  (make-local-variable 'process-environment)
  (dolist (bnd static-opam-env) (setenv (car bnd) (cadr bnd))))

(add-hook 'tuareg-mode-hook 'set-opam-env-locally)
(add-hook 'caml-mode-hook 'set-opam-env-locally)
|elisp}
  in
  Text (def_loadpath :: def_env @ lines_of_string base)

let base_setup = [ ".emacs", dot_emacs_chunk ]

let files = []

let comment = (^) ";; "


module OcpIndent = struct
  let name = "ocp-indent"
  let chunks = [".emacs", Text ["(require 'ocp-indent)"]]
  let files = []
end

module OcpIndex = struct
  let name = "ocp-index"
  let chunks = [".emacs", Text ["(require 'ocp-index)"]]
  let files = []
end

module Merlin = struct
  let name = "merlin"
  let chunks =
    let config = {elisp|
(require 'merlin)
(add-hook 'tuareg-mode-hook 'merlin-mode t)
(add-hook 'caml-mode-hook 'merlin-mode t)
(set 'ocp-index-use-auto-complete nil)
(set 'merlin-use-auto-complete-mode 'easy)
|elisp} in
    [".emacs", Text (lines_of_string config)]
  let files = []
end

let tools = [
  (module OcpIndent : ToolConfig);
  (module OcpIndex : ToolConfig);
  (module Merlin : ToolConfig);
]
