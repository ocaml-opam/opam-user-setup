open OusSig
open OusTypes
open OusMisc

let name = "ocamltop"

let check () = has_command "ocaml" || has_command "utop"

let base_template = []

(* user-config has a hard dep on ocamlfind so this is fine *)
let dot_ocaml_chunk =
  Text ({ocaml|
#use "topfind";;
#thread;;
#camlp4o;;
|ocaml} |> lines_of_string)

let base_setup = [ ".ocamlinit", dot_ocaml_chunk ]

let files = []

let comment s = "(* "^s^" *)" (* Unsafe ! *)

let tools = []
