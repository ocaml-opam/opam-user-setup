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


let dotemacs =
  let ( / ) = Filename.concat in
  let dotemacs = ".emacs" in
  let dotemacsdinit = ".emacs.d" / "init.el" in
  if not (Sys.file_exists (home/dotemacs)) &&
     Sys.file_exists (home/dotemacsdinit)
  then dotemacsdinit
  else dotemacs

let conf_file =
  let ( / ) = Filename.concat in
  ".emacs.d" / "opam-user-setup.el"

let base_template = [
  dotemacs,
  lines_of_string template_base @
  (if opam_var "os" = "darwin" then lines_of_string dot_emacs_tweak_osx else []) @
  lines_of_string template_ocaml
]


(*
 * OPAM and tools setup
 *)

let base_setup =
  let base_opam = {elisp|
(provide 'opam-user-setup)

;; Base configuration for OPAM

(defun opam-shell-command-to-string (command)
  "Similar to shell-command-to-string, but returns nil unless the process
  returned 0, and ignores stderr (shell-command-to-string ignores return value)"
  (let* ((return-value 0)
         (return-string
          (with-output-to-string
            (setq return-value
                  (with-current-buffer standard-output
                    (process-file shell-file-name nil '(t nil) nil
                                  shell-command-switch command))))))
    (if (= return-value 0) return-string nil)))

(defun opam-update-env (switch)
  "Update the environment to follow current OPAM switch configuration"
  (interactive
   (list
    (let ((default
            (car (split-string (opam-shell-command-to-string "opam switch show --safe")))))
      (completing-read
       (concat "opam switch (" default "): ")
       (split-string (opam-shell-command-to-string "opam switch list -s --safe") "\n")
       nil t nil nil default))))
  (let* ((switch-arg (if (= 0 (length switch)) "" (concat "--switch " switch)))
         (command (concat "opam config env --safe --sexp " switch-arg))
         (env (opam-shell-command-to-string command)))
    (when (and env (not (string= env "")))
      (dolist (var (car (read-from-string env)))
        (setenv (car var) (cadr var))
        (when (string= (car var) "PATH")
          (setq exec-path (split-string (cadr var) path-separator)))))))

(opam-update-env nil)

(defvar opam-share
  (let ((reply (opam-shell-command-to-string "opam config var share --safe")))
    (when reply (substring reply 0 -1))))

(add-to-list 'load-path (concat opam-share "/emacs/site-lisp"))

|elisp}
  in
  let base_tools = {elisp|
;; OPAM-installed tools automated detection and initialisation

(defun opam-setup-tuareg ()
  (add-to-list 'load-path (concat opam-share "/tuareg") t)
  (load "tuareg-site-file"))

(defun opam-setup-add-ocaml-hook (h)
  (add-hook 'tuareg-mode-hook h t)
  (add-hook 'caml-mode-hook h t))

(defun opam-setup-complete ()
  (if (require 'company nil t)
    (opam-setup-add-ocaml-hook
      (lambda ()
         (company-mode)
         (defalias 'auto-complete 'company-complete)))
    (require 'auto-complete nil t)))

(defun opam-setup-ocp-indent ()
  (opam-setup-complete)
  (autoload 'ocp-setup-indent "ocp-indent" "Improved indentation for Tuareg mode")
  (autoload 'ocp-indent-caml-mode-setup "ocp-indent" "Improved indentation for Caml mode")
  (add-hook 'tuareg-mode-hook 'ocp-setup-indent t)
  (add-hook 'caml-mode-hook 'ocp-indent-caml-mode-setup  t))

(defun opam-setup-ocp-index ()
  (autoload 'ocp-index-mode "ocp-index" "OCaml code browsing, documentation and completion based on build artefacts")
  (opam-setup-add-ocaml-hook 'ocp-index-mode))

(defun opam-setup-merlin ()
  (opam-setup-complete)
  (require 'merlin)
  (opam-setup-add-ocaml-hook 'merlin-mode)

  (defcustom ocp-index-use-auto-complete nil
    "Use auto-complete with ocp-index (disabled by default by opam-user-setup because merlin is in use)"
    :group 'ocp_index)
  (defcustom merlin-ac-setup 'easy
    "Use auto-complete with merlin (enabled by default by opam-user-setup)"
    :group 'merlin-ac)

  ;; So you can do it on a mac, where `C-<up>` and `C-<down>` are used
  ;; by spaces.
  (define-key merlin-mode-map
    (kbd "C-c <up>") 'merlin-type-enclosing-go-up)
  (define-key merlin-mode-map
    (kbd "C-c <down>") 'merlin-type-enclosing-go-down)
  (set-face-background 'merlin-type-face "skyblue"))

(defun opam-setup-utop ()
  (autoload 'utop "utop" "Toplevel for OCaml" t)
  (autoload 'utop-minor-mode "utop" "Minor mode for utop" t)
  (add-hook 'tuareg-mode-hook 'utop-minor-mode))

(defvar opam-tools
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

(defvar opam-tools-installed (opam-detect-installed-tools))

(defun opam-auto-tools-setup ()
  (interactive)
  (dolist (tool opam-tools)
    (when (member (car tool) opam-tools-installed)
     (funcall (symbol-function (cdr tool))))))

(opam-auto-tools-setup)

|elisp}
  in
  let base_autoload = {elisp|
(require 'opam-user-setup "~/.emacs.d/opam-user-setup.el")
|elisp}
  in
  [ conf_file, Text (lines_of_string base_opam @ lines_of_string base_tools);
    dotemacs, Text (lines_of_string base_autoload) ]

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
(defun opam-tuareg-autoload (fct file doc args)
  (let ((load-path (cons "%s" load-path)))
    (load file))
  (apply fct args))
(when (not (member "tuareg" opam-tools-installed))
  (defun tuareg-mode (&rest args)
    (opam-tuareg-autoload 'tuareg-mode "tuareg" "Major mode for editing OCaml code" args))
  (defun tuareg-run-ocaml (&rest args)
    (opam-tuareg-autoload 'tuareg-run-ocaml "tuareg" "Run an OCaml toplevel process" args))
  (defun ocamldebug (&rest args)
    (opam-tuareg-autoload 'ocamldebug "ocamldebug" "Run the OCaml debugger" args))
  (defalias 'run-ocaml 'tuareg-run-ocaml)
  (defalias 'camldebug 'ocamldebug)
  (add-to-list 'auto-mode-alist '("\\.ml[iylp]?\\'" . tuareg-mode))
  (add-to-list 'auto-mode-alist '("\\.eliomi?\\'" . tuareg-mode))
  (add-to-list 'interpreter-mode-alist '("ocamlrun" . tuareg-mode))
  (add-to-list 'interpreter-mode-alist '("ocaml" . tuareg-mode))
  (dolist (ext '(".cmo" ".cmx" ".cma" ".cmxa" ".cmxs" ".cmt" ".cmti" ".cmi" ".annot"))
    (add-to-list 'completion-ignored-extensions ext)))
|elisp}
        tuareg_dir
    in
    [conf_file, Text (lines_of_string contents)]
  let files = []
  let post_install = []
  let pre_remove = []
end

module OcpIndent = struct
  let name = "ocp-indent"
  let chunks =
    let contents =
      let el = share_dir / "emacs" / "site-lisp" / "ocp-indent.el" in
      Printf.sprintf {elisp|
;; Load ocp-indent from its original switch when not found in current switch
(when (not (assoc "ocp-indent" opam-tools-installed))
  (autoload 'ocp-setup-indent "%s" "Improved indentation for Tuareg mode")
  (autoload 'ocp-indent-caml-mode-setup "%s" "Improved indentation for Caml mode")
  (add-hook 'tuareg-mode-hook 'ocp-setup-indent t)
  (add-hook 'caml-mode-hook 'ocp-indent-caml-mode-setup  t)
  (setq ocp-indent-path %S))
|elisp}
        el el (opam_var "bin" / "ocp-indent")
    in
    [conf_file, Text (lines_of_string contents)]
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

module Ocamlformat = struct
  (* Handled dynamically, invalid in other switches *)
  let name = "ocamlformat"
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
  (module Ocamlformat : ToolConfig);
]
