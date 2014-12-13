open OusTypes

let msg fmt = Printf.kprintf print_endline fmt

let (/) = Filename.concat

let (@>) f g x = g (f x)

module StringMap = Map.Make(struct type t = string let compare = compare end)
type 'a stringmap = 'a StringMap.t

let lines_of_string s =
  let rex = Re.(compile (char '\n')) in
  Re_pcre.split ~rex (String.trim s)

let lines_of_channel ic =
  let rec aux acc =
    match input_line ic with
    | s -> aux (s::acc)
    | exception End_of_file -> acc
  in
  List.rev (aux [])

let lines_of_file f =
  if not (Sys.file_exists f) then [] else
  let ic = open_in f in
  let lines = lines_of_channel ic in
  close_in ic;
  lines

let lines_of_command c =
  let ic = Unix.open_process_in c in
  let lines = lines_of_channel ic in
  close_in ic;
  lines

let lines_to_file lines f =
  let oc = open_out f in
  List.iter (fun line -> output_string oc line; output_char oc '\n') lines;
  close_out oc

let opam_var v =
  let cmd = Printf.sprintf "opam config var %s" v in
  match lines_of_command cmd with
  | [value] -> value
  | _ -> failwith (Printf.sprintf "Bad answer from '%s'" cmd)

let has_command c =
  let cmd = Printf.sprintf "/bin/sh -c command -v %s" c in
  try Sys.command cmd = 0 with Sys_error _ -> false
