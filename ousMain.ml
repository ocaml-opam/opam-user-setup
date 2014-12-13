open OusSig
open OusTypes
open OusMisc

let home =
  try Sys.getenv "HOME"
  with Not_found -> failwith "Could not get the HOME variable"

let opam_prefix = opam_var "prefix"

(** Handles addition, removal and update of chunks within config files *)
module Chunk(Editor: EditorConfig) = struct

  (** Header of inserted chunks must include this string. The full format is
      {v## added by OPAM user-setup for <editor> ## <tool-name> ## <md5> ##v} *)
  let chunk_header_string =
    Printf.sprintf "## added by OPAM user-setup for %s" Editor.name
  let chunk_footer_string =
    Printf.sprintf "## end of OPAM user-setup addition for %s" Editor.name

  let base_lines_of_chunk = function
    | Text lines -> lines

  let lines_md5 lines = Digest.string (String.concat "\n" lines)

  let protect_lines_of_chunk tool lines =
    let md5 = lines_md5 lines in
    (Editor.comment @@ Printf.sprintf "%s / %s ## %s ## you can edit, but keep this line"
       chunk_header_string tool (Digest.to_hex md5))
    :: lines @
    [ Editor.comment @@ Printf.sprintf "%s / %s ## keep this line"
        chunk_footer_string tool ]

  type read_chunk =
    | Line of string (** Normal file string *)
    | Chunk of string * Digest.t * lines option
    (** tool name, current md5, Some contents if user-modified *)

  let read_chunks =
    let re_head = Re.(
        seq [
          str chunk_header_string;
          rep space;
          str "/";
          rep space;
          group (rep (compl [space]));
          rep space;
          str "##";
          rep space;
          group (rep (compl [space]));
          rep space;
          str "##";
        ] |> compile)
    in
    let re_foot = Re.(
        seq [
          str chunk_footer_string;
          rep space;
          str "/";
          rep space;
          group (rep (compl [space]));
          rep space;
          str "##";
        ] |> compile)
    in
    fun filename lines ->
      let rec aux acc = function
        | [] -> List.rev acc
        | line :: lines ->
          match Re.exec re_head line with
          | exception Not_found -> aux (Line line :: acc) lines
          | ss ->
            let tool = Re.get ss 1 in
            let md5 = Digest.from_hex (Re.get ss 2) in
            let rec read_chunk chunk_contents = function
              | [] ->
                msg "Error: unclosed configuration chunk for %S in %s at EOF"
                  tool filename;
                aux (Line line :: acc) (List.rev_append chunk_contents lines)
              | cline::lines ->
                if Re.execp re_head cline then (
                  msg "Error: unclosed configuration chunk for %S in %s at \
                       %s chunk start"
                    tool filename (Re.get ss 1);
                  aux (Line line :: acc)
                    (List.rev_append chunk_contents (cline::lines))
                ) else
                match Re.exec re_foot cline with
                | exception Not_found -> read_chunk (cline::chunk_contents) lines
                | ss ->
                  let endtool = Re.get ss 1 in
                  if endtool <> tool then
                    msg "Warning: chunk for %S closed as %S in %s"
                      tool endtool filename;
                  let contents = List.rev chunk_contents in
                  let actual_md5 = lines_md5 contents in
                  let changes =
                    if actual_md5 = md5 then None
                    else Some (line :: contents @ [cline])
                  in
                  aux (Chunk (tool, md5, changes) :: acc) lines
            in
            read_chunk [] lines
      in
      aux [] lines

  let update_chunks filename lines tools_chunks_list =
    let current_contents = read_chunks filename lines in
    let chunk_lines tool chunk =
      protect_lines_of_chunk tool (base_lines_of_chunk chunk)
    in
    let chunk_md5 chunk = lines_md5 (base_lines_of_chunk chunk) in
    let take x assoc = List.assoc x assoc, List.remove_assoc x assoc in
    let rec aux tools_chunks_list acc = function
      | [] -> (* Append all remaining chunks at end *)
        tools_chunks_list |> List.fold_left (fun acc (tool, chunk) ->
            msg "Adding config chunk for %s in %s" tool filename;
            List.rev_append (chunk_lines tool chunk) acc)
          acc
        |> List.rev
      | Line l :: lines ->
        aux tools_chunks_list (l :: acc) lines
      | Chunk (tool, old_md5, None) :: lines ->
        (try
           let chunk, tools_chunks_list = take tool tools_chunks_list in
           (* Insert chunk *)
           if old_md5 <> chunk_md5 chunk then
             msg "Updating configuration chunk for %s in %s" tool filename;
           aux tools_chunks_list (List.rev_append (chunk_lines tool chunk) acc) lines
         with Not_found ->
           msg "Removing configuration for %s from %s" tool filename;
           aux tools_chunks_list acc lines)
      | Chunk (tool, md5, Some changes) :: lines ->
        try
          let chunk, tools_chunks_list = take tool tools_chunks_list in
          if md5 <> chunk_md5 chunk then
            msg "Chunk for %s manually changed in %s, not applying new version"
              tool filename;
          aux tools_chunks_list (List.rev_append changes acc) lines
        with Not_found ->
          msg "Manually changed config for %s in %s: leaving as is"
            tool filename;
          aux tools_chunks_list (List.rev_append changes acc) lines
    in
    aux tools_chunks_list [] current_contents
end

let editors = [
  (module Emacs: EditorConfig);
]

let link_file ?(remove=false) (opam_file,filename) =
  let src = opam_prefix/opam_file in
  let dst = home/filename in
  let islink f =
    try (Unix.stat f).Unix.st_kind = Unix.S_LNK with Unix.Unix_error _ -> false
  in
  if islink dst then Unix.unlink dst;
  if not (Sys.file_exists dst) && not remove then Unix.link src dst

let tool_name t =
  let module T = (val t: ToolConfig) in T.name
let tool_files t =
  let module T = (val t: ToolConfig) in T.files
let tool_chunks t =
  let module T = (val t: ToolConfig) in T.chunks

let () =
  let args = match Array.to_list Sys.argv with _::l -> l | [] -> [] in
  let options,tool_names =
    List.partition (fun s -> String.length s >= 1 && s.[0] = '-') args
  in
  let remove = options = ["--remove"] && tool_names = [] in
  if not remove && options <> [] then (
    msg "Usage: %s [--remove] [tool names]" Sys.argv.(0);
    exit 2
  );
  editors |> List.iter @@ fun e ->
  let module E = (val e: EditorConfig) in
  let tools, remove_tools =
    if remove then [],E.tools else
      List.partition
        (fun t -> List.mem (tool_name t) tool_names)
        E.tools
  in
  if List.length tools < List.length tool_names then
    msg "Warning: some unrecognised tool names in %S for %s"
      (String.concat " " tool_names) E.name;
  (E.base_template
   |> List.iter @@ fun (filename, lines) ->
   let f = home/filename in
   if not remove && not (Sys.file_exists f) then
     (msg "Installing new config file template for %s at %s" E.name f;
      lines_to_file lines f));
  E.files |> List.iter @@ link_file ~remove;
  remove_tools |> List.map tool_files
  |> List.iter @@ List.iter @@ link_file ~remove:true;
  tools |> List.map tool_files
  |> List.iter @@ List.iter @@ link_file;
  let add_chunks ?(remove=false) tool list chunks =
    list |> List.fold_left (fun chunks (filename, chk) ->
        let tc = try StringMap.find filename chunks with Not_found -> [] in
        let tc = if remove then tc else (tool,chk)::tc in
        StringMap.add filename tc chunks)
      chunks
  in
  let add_tools_chunks ?remove tools chunks =
    List.fold_left (fun chunks t ->
        add_chunks ?remove (tool_name t) (tool_chunks t) chunks)
      chunks tools
  in
  StringMap.empty
  |> add_chunks ~remove "base" E.base_setup
  |> add_tools_chunks ~remove:true remove_tools
  |> add_tools_chunks tools
  |> StringMap.iter @@ fun filename tools_chunks_list ->
  let f = home/filename in
  let lines = lines_of_file f in
  let module C = Chunk(E) in
  let lines = C.update_chunks filename lines (List.rev tools_chunks_list) in
  lines_to_file lines f
