(** Filename relative to the user's HOME dir (eg. ".vimrc") *)
type filename = string

(** Filename relative to the current OPAM switch prefix (eg.
    "share/emacs/site-lisp/ocp-indent.el") *)
type opam_filename = string

(** Used for file contents (one string without endline per line) *)
type lines = string list

(** A few text lines that may be added or replaced in configuration files *)
type file_chunk =
  | Text of lines
  (* | Json ... | Xml ... for other config-file formats *)
