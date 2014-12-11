(** Filename relative to the user's HOME dir (eg. ".vimrc") *)
type filename = string

(** Filename relative to the current OPAM switch prefix (eg.
    "share/emacs/site-lisp/ocp-indent.el") *)
type opam_filename = string

(** Used for file contents (one string without endline per line) *)
type lines = string list

type variable = ..

(** Strings with variable replacements *)
type var_text = String of string | Ident of variable

(** A few text lines that may be added or replaced in configuration files *)
type file_chunk =
  | Text of var_text list list
  (* | Json ... | Xml ... for other config-file formats *)
