open OusSig
open OusTypes
open OusMisc

let name = "emacs"

let check () = has_command "emacs"

(*
 * Generic template for .emacs
 *)

let template_base = {elisp|
;; Basic .emacs with a good set of defaults, to be used as template for usage
;; with OCaml and OPAM
;;
;; Author: Louis Gesbert <louis.gesbert@ocamlpro.com>
;; Released under CC0

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
 '(line-move-visual t)
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

|elisp}


let template_ocaml = {elisp|
;; OCaml configuration
;;  - better error and backtrace matching

(defun set-ocaml-error-regexp ()
  (set
   'compilation-error-regexp-alist
   (list '("[Ff]ile \\(\"\\(.*?\\)\", line \\(-?[0-9]+\\)\\(, characters \\(-?[0-9]+\\)-\\([0-9]+\\)\\)?\\)\\(:\n\\(\\(Warning .*?\\)\\|\\(Error\\)\\):\\)?"
    2 3 (5 . 6) (9 . 11) 1 (8 compilation-message-face)))))

(add-hook 'tuareg-mode-hook 'set-ocaml-error-regexp)
(add-hook 'caml-mode-hook 'set-ocaml-error-regexp)

|elisp}


let dot_emacs_tweak_osx = {elisp|
;; -- Tweaks for OS X -------------------------------------
;; Tweak for problem on OS X where Emacs.app doesn't run the right
;; init scripts when invoking a sub-shell
(defun set-exec-path-from-shell-PATH ()
  "Set up Emacs' `exec-path' and PATH environment variable to
  match that used by the user's shell.

This is particularly useful under Mac OSX, where GUI apps are not
started from a shell."
  (interactive)
  (let ((path-from-shell
         (replace-regexp-in-string
          "[ \t\n]*$" ""
          (shell-command-to-string "$SHELL --login -i -c 'echo $PATH'"))
         ))
    (setenv "PATH" path-from-shell)
    (setq exec-path (split-string path-from-shell path-separator)))
  )

(set-exec-path-from-shell-PATH)

|elisp}


let base_template = [
  ".emacs",
  lines_of_string template_base @
  (if opam_var "os" = "darwin" then lines_of_string dot_emacs_tweak_osx else []) @
  lines_of_string template_ocaml
]


(*
 * OPAM and tools setup
 *)

let base_setup =
  let base = {elisp|
;; Base configuration for OPAM

(defun opam-shell-command-to-string (command)
  "Similar to shell-command-to-string, but returns nil unless the process
  returned 0 (shell-command-to-string ignores return value)"
  (let* ((return-value 0)
         (return-string
          (with-output-to-string
            (setq return-value
                  (with-current-buffer standard-output
                    (process-file shell-file-name nil t nil
                                  shell-command-switch command))))))
    (if (= return-value 0) return-string nil)))

(defun opam-update-env ()
  "Update the environment to follow current OPAM switch configuration"
  (interactive)
  (let ((env (opam-shell-command-to-string "opam config env --sexp")))
    (when env
      (dolist (var (car (read-from-string env)))
        (setenv (car var) (cadr var))
        (when (string= (car var) "PATH")
          (setq exec-path (split-string (cadr var) path-separator)))))))

(opam-update-env)

(setq opam-share
  (let ((reply (opam-shell-command-to-string "opam config var share")))
    (when reply (substring reply 0 -1))))

(add-to-list 'load-path (concat opam-share "/emacs/site-lisp"))

|elisp}
  in
  let tools = {elisp|
;; OPAM-installed tools automated detection and initialisation

(defun opam-setup-tuareg ()
  (add-to-list 'load-path (concat opam-share "/tuareg") t)
  (load "tuareg-site-file"))

(defun opam-setup-ocp-indent ()
  (require 'ocp-indent))

(defun opam-setup-ocp-index ()
  (require 'ocp-index))

(defun opam-setup-merlin ()
  (require 'merlin)
  (add-hook 'tuareg-mode-hook 'merlin-mode t)
  (add-hook 'caml-mode-hook 'merlin-mode t)
  (set-default 'ocp-index-use-auto-complete nil)
  (set-default 'merlin-use-auto-complete-mode 'easy)
  ;; So you can do it on a mac, where `C-<up>` and `C-<down>` are used
  ;; by spaces.
  (define-key merlin-mode-map
    (kbd "C-c <up>") 'merlin-type-enclosing-go-up)
  (define-key merlin-mode-map
    (kbd "C-c <down>") 'merlin-type-enclosing-go-down)
  (set-face-background 'merlin-type-face "skyblue"))

(defun opam-setup-utop ()
  (autoload 'utop "utop" "Toplevel for OCaml" t)
  (autoload 'utop-setup-ocaml-buffer "utop" "Toplevel for OCaml" t)
  (add-hook 'tuareg-mode-hook 'utop-setup-ocaml-buffer))

(setq opam-tools
  '(("tuareg" . opam-setup-tuareg)
    ("ocp-indent" . opam-setup-ocp-indent)
    ("ocp-index" . opam-setup-ocp-index)
    ("merlin" . opam-setup-merlin)
    ("utop" . opam-setup-utop)))

(defun opam-detect-installed-tools ()
  (let*
      ((command "opam list --installed --short --safe --color=never")
       (names (mapcar 'car opam-tools))
       (command-string (mapconcat 'identity (cons command names) " "))
       (reply (opam-shell-command-to-string command-string)))
    (when reply (split-string reply))))

(setq opam-tools-installed (opam-detect-installed-tools))

(defun opam-auto-tools-setup ()
  (interactive)
  (dolist
      (f (mapcar (lambda (x) (cdr (assoc x opam-tools))) opam-tools-installed))
    (funcall (symbol-function f))))

(opam-auto-tools-setup)

|elisp}
  in
  [ ".emacs", Text (lines_of_string base @ lines_of_string tools) ]

let files = []

let comment = (^) ";; "

let share_dir = opam_var "share"

module Tuareg = struct
  let name = "tuareg"
  let chunks =
    let tuareg_dir =
      if Sys.file_exists (share_dir / "emacs" / "site-lisp" / "tuareg.el")
      then share_dir / "emacs" / "site-lisp"
      else share_dir / "tuareg" (* legacy *)
    in
    let contents =
      Printf.sprintf {elisp|
;; Set to autoload tuareg from its original switch when not found in current
;; switch (don't load tuareg-site-file as it adds unwanted load-paths)
(when (not (assoc "tuareg" opam-tools-installed))
  (autoload 'tuareg-mode "%s/tuareg" "Major mode for editing OCaml code" t nil)
  (autoload 'tuareg-run-ocaml "%s/tuareg" "Run an OCaml toplevel process" t nil)
  (autoload 'ocamldebug "%s/ocamldebug" "Run the OCaml debugger" t nil)
  (defalias 'run-ocaml 'tuareg-run-ocaml)
  (defalias 'camldebug 'ocamldebug)
  (add-to-list 'auto-mode-alist '("\\.ml[iylp]?\\'" . tuareg-mode))
  (dolist (ext '(".cmo" ".cmx" ".cma" ".cmxa" ".cmi" ".annot"))
    (add-to-list 'completion-ignored-extensions ext)))
|elisp}
        tuareg_dir tuareg_dir tuareg_dir
    in
    [".emacs", Text (lines_of_string contents)]
  let files = []
  let post_install = []
  let pre_remove = []
end

module OcpIndent = struct
  let name = "ocp-indent"
  let chunks =
    let contents =
      Printf.sprintf {elisp|
;; Load ocp-indent from its original switch when not found in current switch
(when (not (assoc "ocp-indent" opam-tools-installed))
  (load-file %S)
  (setq ocp-indent-path %S))
|elisp}
        (share_dir / "emacs" / "site-lisp" / "ocp-indent.el")
        (opam_var "bin" / "ocp-indent")
    in
    [".emacs", Text (lines_of_string contents)]
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
  let name = "merlin"
  let chunks = []
  let files = []
  let post_install = []
  let pre_remove = []
end

let tools = [
  (module Tuareg : ToolConfig);
  (module OcpIndent : ToolConfig);
  (module OcpIndex : ToolConfig);
  (module Merlin : ToolConfig);
]
