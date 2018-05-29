open OusTypes

let msg fmt = Printf.kprintf print_endline fmt

external (@@) : ('a -> 'b) -> 'a -> 'b = "%apply"

external (|>) : 'a -> ('a -> 'b) -> 'b = "%revapply"

let (/) = Filename.concat

let (@>) f g x = g (f x)

module StringMap = Map.Make(struct type t = string let compare = compare end)
type 'a stringmap = 'a StringMap.t

let lines_of_string s =
  let rex = Re.(compile (char '\n')) in
  let s = Re.(replace_string (compile @@ seq [ bos; rep space]) "" s) in
  let s = Re.(replace_string (compile @@ seq [ rep space; eos]) "" s) in
  Re_pcre.split ~rex s

let lines_of_channel ic =
  let rec aux acc =
    let l = try Some (input_line ic) with End_of_file -> None in
    match l with
    | Some s -> aux (s::acc)
    | None -> acc
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

let rec mkdir_p dir =
  if Sys.file_exists dir then () else
    (mkdir_p (Filename.dirname dir);
     Unix.mkdir dir 0o777)

let lines_to_file ?(remove_if_empty=false) lines f =
  if remove_if_empty && lines = [] && Sys.file_exists f then Unix.unlink f else
  mkdir_p (Filename.dirname f);
  let oc = open_out f in
  List.iter (fun line -> output_string oc line; output_char oc '\n') lines;
  close_out oc

let opam_var v =
  let cmd = Printf.sprintf "opam config var %s" v in
  match lines_of_command cmd with
  | [value] -> value
  | _ -> failwith (Printf.sprintf "Bad answer from '%s'" cmd)

let home =
  try Sys.getenv "HOME"
  with Not_found -> failwith "Could not get the HOME variable"

let has_command c =
  let cmd = Printf.sprintf "/bin/sh -c \"command -v %s\" >/dev/null" c in
  try Sys.command cmd = 0 with Sys_error _ -> false
