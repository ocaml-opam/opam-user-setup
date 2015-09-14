#!/usr/bin/env ocaml

let () =
  try Topdirs.dir_directory (Sys.getenv "OCAML_TOPLEVEL_PATH")
  with Not_found -> ()
;;
#use "topfind";;
#require "re";;

(** This is a dumb, limited rewriter for the [{xxx| |xxx}] quotations, that
    weren't available in OCaml 4.01. Only one beginning/end token is allowed per
    line, no error handling, probably escaping bugs... But this is enough
    for just allowing to compile on earlier OCaml versions. *)

let start_quot_re = Re.(compile (seq [char '{'; group (rep alnum); char '|']))
let end_quot_re name = Re.(compile (seq [char '|'; str name; char '}']))

let rec next ic =
  let line = input_line ic in
  let quot = try Some (Re.exec start_quot_re line) with Not_found -> None in
  match quot with
  | Some subs ->
    let match_start, match_end = Re.get_ofs subs 0 in
    print_string (String.sub line 0 match_start);
    let end_re = end_quot_re (Re.get subs 1) in
    let rec get_s acc =
      let line = input_line ic in
      try
        let subs = Re.exec end_re line in
        let match_start, match_end = Re.get_ofs subs 0 in
        let ss = List.rev (String.sub line 0 match_start :: acc) in
        print_char '\"';
        List.iter (fun s ->
            print_string (String.escaped s);
            print_string "\\n\\\n")
          ss;
        print_char '\"';
        print_string
          (String.sub line match_end (String.length line - match_end));
        print_char '\n'
      with Not_found -> get_s (line::acc)
    in
    get_s [String.sub line match_end (String.length line - match_end)];
    next ic
  | None ->
    print_string line; print_char '\n'; next ic

let () =
  let ic = open_in (Sys.argv.(1)) in
  try next ic with End_of_file -> close_in ic
