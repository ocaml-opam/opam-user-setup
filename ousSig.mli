open OusTypes

(** We call "editor" third-party software installed on the machine for which we
    want to provide configuration. We call "tool" an OCaml-related tool,
    installed with OPAM, that provides functionality to editors.

    Note that the configuration should be *static* for the current switch.
    Because it's simpler, because it's our primary use-case, but mostly because
    it wouldn't be consistent otherwise since we depend on the tools installed
    on the current switch.
*)

(** Modules implementing this signature reflect the configuration needed for a
    given tool and a given editor. *)
module type ToolConfig = sig
  (** The name of the tool *)
  val name : string

  (** Pieces of text that need to be present in the given files. To keeps things
      simple, there should only be one chunk per tool per file *)
  val chunks : (filename * file_chunk) list

  (** These are configuration files that need to be included somewhere in the
      file tree. They will be linked whenever possible and are not supposed to
      be changed by the user. *)
  val files : (opam_filename * filename) list

  (** List of hooks that should be run after installation of the tool
      @param [dry_run] *)
  val post_install : (bool -> unit) list

  (** List of hooks that should be run before removal of the tool
      @param [dry_run] *)
  val pre_remove : (bool -> unit) list
end

(** Modules implementing this signature reflect the configuration needed for a
    given editor, as a base and a list of per-tool configuration *)
module type EditorConfig = sig
  (** The name of the editor *)
  val name : string

  (** Checks if an instance of the editor is installed on the system *)
  val check : unit -> bool

  (** These files are base configuration files for the given editor, the
      templates will be installed only if no configuration exists yet *)
  val base_template : (filename * lines) list

  (** These chunks always need to be installed to the given files. To include
      OPAM search dirs for example *)
  val base_setup : (filename * file_chunk) list

  (** These are configuration files that need to be included somewhere in the
      file tree. They will be linked whenever possible and are not supposed to
      be changed by the user. *)
  val files : (opam_filename * filename) list

  (** Transforms a single line for inclusion as comment in a config file *)
  val comment : string -> string

  val tools : (module ToolConfig) list
end
