open OusTypes

(** Output of messages (stdout) *)
val msg : ('a, unit, string, unit) format4 -> 'a

(** Filename concat *)
val (/): string -> string -> string

(** Reverse composition *)
val (@>): ('a -> 'b) -> ('b -> 'c) -> ('a -> 'c)

(** Function application, with lower priority *)
val (@@): ('a -> 'b) -> 'a -> 'b

(** Reverse function application *)
val (|>): 'a -> ('a -> 'b) -> 'b

module StringMap: Map.S with type key = string
type 'a stringmap = 'a StringMap.t

(** Cuts a string into lines *)
val lines_of_string: string -> lines

(** Returns the empty list if the file doesn't exist. *)
val lines_of_file: string -> lines

(** Runs a command through /bin/sh and returns the lines from its standard
    output once finished *)
val lines_of_command: string -> lines

(** Writes a list of lines to a file. [remove_if_empty] defaults to false. *)
val lines_to_file: ?remove_if_empty:bool -> lines -> string -> unit

(** Query OPAM for a variable (see 'OPAMCLI=2.0 opam config list' or 'opam var --cli 2.1') *)
val opam_var: string -> string

(** The current user's home directory (as given by environment variable HOME) *)
val home: string

(** Checks if the given command is available on the system *)
val has_command: string -> bool

(** Creates the directory and its parents, if it doesn't exist *)
val mkdir_p: string -> unit
