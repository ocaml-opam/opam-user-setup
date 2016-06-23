open OusSig
open OusTypes
open OusMisc

let opam_prefix = opam_var "prefix"

(** Handles addition, removal and update of chunks within config files *)
module Chunk(E: EditorConfig) = struct

  (** Header of inserted chunks must include this string. The full format is
      {v## added by OPAM user-setup for <editor> ## <tool-name> ## <md5> ##v} *)
  let chunk_header_string =
    Printf.sprintf "## added by OPAM user-setup for %s" E.name
  let chunk_footer_string =
    Printf.sprintf "## end of OPAM user-setup addition for %s" E.name

  let base_lines_of_chunk = function
    | Text lines -> lines

  let lines_md5 lines = Digest.string (String.concat "\n" lines)

  let protect_lines_of_chunk tool lines =
    let md5 = lines_md5 lines in
    (E.comment @@ Printf.sprintf "%s / %s ## %s ## you can edit, but keep this line"
       chunk_header_string tool (Digest.to_hex md5))
    :: lines @
    [ E.comment @@ Printf.sprintf "%s / %s ## keep this line"
        chunk_footer_string tool ]

  type read_chunk =
    | Line of string (** Normal file string *)
    | Chunk of string * Digest.t * bool * lines
    (** tool name, current md5, dirty, contents *)

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
          let r = try Some (Re.exec re_head line) with Not_found -> None in
          match r with
          | None -> aux (Line line :: acc) lines
          | Some ss ->
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
                let r = try Some (Re.exec re_foot cline)
                  with Not_found -> None in
                match r with
                | None ->
                  read_chunk (cline::chunk_contents) lines
                | Some ss ->
                  let endtool = Re.get ss 1 in
                  if endtool <> tool then
                    msg "Warning: chunk for %S closed as %S in %s"
                      tool endtool filename;
                  let contents = List.rev chunk_contents in
                  let actual_md5 = lines_md5 contents in
                  let dirty = actual_md5 <> md5 in
                  let contents = line :: contents @ [cline] in
                  aux (Chunk (tool, md5, dirty, contents) :: acc) lines
            in
            read_chunk [] lines
      in
      aux [] lines

  let check_chunks filename lines tools_chunks_list =
    let current_contents = read_chunks filename lines in
    let file_state =
      List.fold_left (fun acc -> function
          | Line _ -> acc
          | Chunk (tool, old_md5, dirty, contents) ->
            try
              let chunk = List.assoc tool tools_chunks_list in
              let current = old_md5 = lines_md5 (base_lines_of_chunk chunk) in
              (tool, ((if current then `Up_to_date else `Obsolete), dirty)) ::
              acc
            with Not_found ->
              (tool, (`Unknown, dirty)) :: acc)
        [] current_contents
    in
    List.fold_left (fun acc (tool, chunk) ->
        if List.mem_assoc tool acc then acc
        else (tool, (`Absent, false)) :: acc)
      file_state tools_chunks_list
    |> List.rev

  let chunk_lines tool chunk =
    protect_lines_of_chunk tool (base_lines_of_chunk chunk)

  let chunk_md5 chunk = lines_md5 (base_lines_of_chunk chunk)

  let update_chunks force keep filename lines tools_chunks_list =
    let take x assoc = List.assoc x assoc, List.remove_assoc x assoc in
    let rec aux tools_chunks_list acc = function
      | [] -> (* Append all remaining chunks at end *)
        List.fold_right (fun (tool, chunk) acc ->
            msg "%s > %s > %s: adding configuration" E.name tool filename;
            List.rev_append (chunk_lines tool chunk) acc)
          tools_chunks_list acc
        |> List.rev
      | Line l :: lines ->
        aux tools_chunks_list (l :: acc) lines
      | Chunk (tool, old_md5, dirty, contents) :: lines ->
        try
          let chunk, tools_chunks_list = take tool tools_chunks_list in
          if old_md5 = chunk_md5 chunk && not dirty then
            (msg "%s > %s > %s: up to date" E.name tool filename;
             aux tools_chunks_list (List.rev_append contents acc) lines)
          else if not dirty || force then
            (msg "%s > %s > %s: updating configuration" E.name tool filename;
             aux tools_chunks_list
               (List.rev_append (chunk_lines tool chunk) acc) lines)
          else
            (msg "%s > %s > %s: manual changes: leaving as is" E.name tool filename;
             aux tools_chunks_list (List.rev_append contents acc) lines)
        with Not_found ->
          if keep || dirty then
            (msg "%s > %s > %s: keeping configuration" E.name tool filename;
             aux tools_chunks_list (List.rev_append contents acc) lines)
          else
            (msg "%s > %s > %s: removing configuration" E.name tool filename;
             aux tools_chunks_list acc lines)
    in
    aux tools_chunks_list [] (read_chunks filename lines)


  let remove_chunks force filename lines tools_list =
    let rec aux acc = function
      | [] -> List.rev acc
      | Line l :: lines ->
        aux (l :: acc) lines
      | Chunk (tool,_,dirty,contents) :: lines when List.mem tool tools_list ->
        if not dirty || force then
          (msg "%s > %s > %s: removing configuration" E.name tool filename;
           aux acc lines)
        else
          (msg "%s > %s > %s: manual changes detected: not removing"
             E.name tool filename;
           aux (List.rev_append contents acc) lines)
      | Chunk (tool,_,_,contents) :: lines ->
        aux (List.rev_append contents acc) lines
    in
    aux [] (read_chunks filename lines)

end

let link_file name force dry_run (opam_file,filename) =
  let src = opam_prefix/opam_file in
  let dst = home/filename in
  let exists = Sys.file_exists dst in
  let linksto = try Some (Unix.readlink dst) with Unix.Unix_error _ -> None in
  if linksto = Some src then
    msg "%s > %s: up to date" name filename
  else if not exists || linksto <> None || force then
    (msg "%s > %s: %slinking from %s"
       name filename (if linksto <> None then "re-" else "") opam_file;
     if not dry_run then (
       if linksto <> None || exists then Unix.unlink dst
       else mkdir_p (Filename.dirname dst);
       Unix.symlink src dst))
  else
    msg "%s > %s: file exists, not linking from %s" name filename opam_file

let unlink_file name force dry_run (opam_file,filename) =
  let src = opam_prefix/opam_file in
  let dst = home/filename in
  let exists = Sys.file_exists dst in
  let linksto = try Some (Unix.readlink dst) with Unix.Unix_error _ -> None in
  if linksto = Some src || force && (exists || linksto <> None) then
    (msg "%s > %s: removing %s"
       name dst (if linksto = None then "file" else "link");
     if not dry_run then Unix.unlink dst)
  else if exists then
    msg "%s > %s: not removing (not the expected link)" name dst

let editors = [
  (module Ocamltop: EditorConfig);
  (module Emacs: EditorConfig);
  (module Vim: EditorConfig);
  (module Gedit: EditorConfig);
  (module Sublime: EditorConfig);
]

let editor_name e =
  let module E = (val e: EditorConfig) in E.name

let tool_name t =
  let module T = (val t: ToolConfig) in T.name
let tool_files t =
  let module T = (val t: ToolConfig) in T.files
let tool_chunks t =
  let module T = (val t: ToolConfig) in T.chunks
let tool_pre_remove t =
  let module T = (val t: ToolConfig) in T.pre_remove
let tool_post_install t =
  let module T = (val t: ToolConfig) in T.post_install

let tools_map =
  List.fold_left
    (fun acc editor ->
       let module Editor = (val editor: EditorConfig) in
       List.fold_left (fun acc tool ->
           StringMap.add (tool_name tool) tool acc)
         acc Editor.tools)
    StringMap.empty editors

let write_template name dry_run (filename, lines) =
  let f = home/filename in
  if not (Sys.file_exists f) then
    (msg "%s > %s: installing new config file template" name f;
     if not dry_run then lines_to_file lines f)
  else
    msg "%s > %s: already exists, not installing base template"
      name filename

let editor_chunks ?tool_names e =
  let module E = (val e: EditorConfig) in
  let add_chunks tool list chunks =
    list |> List.fold_left (fun chunks (filename, chk) ->
        let tc = try StringMap.find filename chunks with Not_found -> [] in
        StringMap.add filename ((tool,chk)::tc) chunks)
      chunks
  in
  let filter t = match tool_names with
    | None -> true
    | Some tn -> List.mem (tool_name t) tn
  in
  let chunk_map = add_chunks "base" E.base_setup StringMap.empty in
  List.fold_left (fun chunks t ->
      if filter t then add_chunks (tool_name t) (tool_chunks t) chunks
      else chunks)
    chunk_map E.tools

let installed_tools () =
  List.filter (fun tool ->
      bool_of_string (opam_var (tool^":installed"))
    )
    (List.map fst (StringMap.bindings tools_map))

let setup_editor tool_names force keep dry_run editor =
  let module E = (val editor: EditorConfig) in
  let tools, remove_tools =
    List.partition
      (fun t -> List.mem (tool_name t) tool_names)
      E.tools
  in
  let remove_tools = if keep then [] else remove_tools in
  remove_tools |> List.iter @@ tool_pre_remove @> List.iter
    (fun f -> f dry_run);
  E.base_template |> List.iter (write_template E.name dry_run);
  E.files |> List.iter @@ link_file E.name force dry_run;
  remove_tools |> List.iter (fun tool ->
      tool_files tool |> List.iter @@
      unlink_file (E.name ^" > "^ tool_name tool) force dry_run);
  tools |> List.iter (fun tool ->
      tool_files tool |> List.iter @@
      link_file (E.name ^" > "^ tool_name tool) force dry_run);
  editor_chunks ~tool_names editor
  |> StringMap.iter @@ (fun filename tclist ->
      let f = home/filename in
      let lines = lines_of_file f in
      let module C = Chunk(E) in
      let lines = C.update_chunks force keep filename lines tclist in
      if not dry_run then lines_to_file ~remove_if_empty:true lines f);
  tools |> List.iter @@ tool_post_install @> List.iter (fun f -> f dry_run)

let remove_editor tool_names force dry_run editor =
  let module E = (val editor: EditorConfig) in
  let tools =
    List.filter
      (fun t -> List.mem (tool_name t) tool_names)
      E.tools
  in
  tools |> List.iter @@ tool_pre_remove @> List.iter (fun f -> f dry_run);
  tools |> List.iter (fun tool ->
      tool_files tool |> List.iter @@
      unlink_file (E.name ^" > "^ tool_name tool) force dry_run);
  editor_chunks ~tool_names editor
  |> StringMap.iter @@ fun filename tclist ->
  let f = home/filename in
  let lines = lines_of_file f in
  let module C = Chunk(E) in
  let lines = C.remove_chunks force filename lines (List.map fst tclist) in
  if not dry_run then lines_to_file ~remove_if_empty:true lines f

let status e =
  let module E = (val e: EditorConfig) in
  let link_files =
    List.fold_left (fun acc tool ->
        List.fold_left (fun acc (opam_file, filename) ->
            let uptodate =
              try Unix.readlink (home/filename) = opam_prefix/opam_file
              with Unix.Unix_error _ -> false
            in
            (filename, [tool_name tool,
                        if uptodate then "link installed"
                        else if Sys.file_exists (home/filename)
                        then "different version or switch"
                        else "absent"])
            :: acc)
          acc (tool_files tool))
      [] E.tools
  in
  StringMap.fold (fun filename tools_chunks_list acc ->
      let f = home/filename in
      let lines = lines_of_file f in
      let module C = Chunk(E) in
      let c = C.check_chunks filename lines (List.rev tools_chunks_list) in
      (filename,
       List.map (fun (tool, (status, changed)) ->
           tool, Printf.sprintf "%s%s" (match status with
               | `Absent -> "absent"
               | `Unknown -> "unknown tool"
               | `Up_to_date -> "current"
               | `Obsolete -> "different version or switch")
             (if changed then " (user changed)" else ""))
         c)
      :: acc)
    (editor_chunks e) link_files

let print_status editors =
  Printf.printf "# Available editors and configuration status:\n";
  editors |> List.iter @@ fun e ->
  let module E = (val e: EditorConfig) in
  Printf.printf "\n## %s (%s)\n" E.name
    (if E.check () then "installed" else "uninstalled");
  status e |> List.iter @@ fun (file, chunks) ->
  Printf.printf "%-39s\t%s" file @@
  String.concat "                                        " @@
  (chunks |> List.map @@ fun (label, txt) ->
   Printf.sprintf "%-16s%s\n" label txt)

open Cmdliner

let tool_names_arg =
  let tools =
    List.map (fun (name,_) -> name,name) (StringMap.bindings tools_map)
  in
  let doc = "The tools (opam packages) to setup or remove. By default, \
             installed opam packages are detected. Any package absent from \
             this list will be unconfigured, unless `--keep' is specified"
  in
  let arg = Arg.(value & pos_all (enum tools) [] & info ~doc []) in
  let aux = function
    | [] -> installed_tools ()
    | tools -> tools
  in
  Term.(pure aux $ arg)

let editors_arg =
  let editors_enum =
    List.map (fun e -> let name = editor_name e in name, name) editors
  in
  let doc = "Editing tools (e.g. emacs, vim, the ocaml toplevel...) to \
             consider for configuration. By default, they are detected"
  in
  let arg =
    Arg.(value & opt_all (list (enum editors_enum)) [] & info ~doc ["editors"])
  in
  let aux names =
    let names = List.flatten names in
    List.filter (fun e -> List.mem (editor_name e) names) editors
  in
  Term.(pure aux $ arg)

let default_all_editors_arg =
  let aux eds = if eds = [] then editors else eds in
  Term.(pure aux $ editors_arg)

let default_installed_editors_arg =
  let aux eds =
    if eds = [] then
      List.filter (fun e ->
          let module E = (val e: EditorConfig) in E.check ())
        editors
    else eds
  in
  Term.(pure aux $ editors_arg)

let force_arg =
  let doc = "Install or remove configuration even when manual modifications \
             are detected (this won't override your editor configuration with \
             the included templates, for that, you should manually remove it)"
  in
  Arg.(value & flag & info ~doc ["f";"force"])

let keep_arg =
  let doc = "If set, configuration for tools that aren't detected or \
             explicitely listed is kept (the default is to remove it)"
  in
  Arg.(value & flag & info ~doc ["k";"keep"])

let dry_run_arg =
  let doc = "Display diffs and summary of actions, don't perform them" in
  Arg.(value & flag & info ~doc ["dry-run"])

let status_cmd =
  let doc = "displays the current installation status." in
  Term.(pure print_status $ default_all_editors_arg),
  Term.info "status" ~doc

let install_cmd =
  let doc = "Install configuration for the detected or specified tools" in
  let aux editors tool_names force keep dry_run =
    editors |> List.iter @@ fun e ->
    setup_editor tool_names force keep dry_run e
  in
  Term.(pure aux
        $default_installed_editors_arg $tool_names_arg
        $force_arg $keep_arg $dry_run_arg),
  Term.info "install" ~doc

let remove_cmd =
  let doc = "Remove configuration of tools. If no tools are specified, all \
             configuration is removed"
  in
  let aux editors tool_names force dry_run =
    editors |> List.iter @@ fun e ->
    remove_editor tool_names force dry_run e
  in
  Term.(pure aux $default_all_editors_arg $tool_names_arg $force_arg $dry_run_arg),
  Term.info "remove" ~doc

let default_cmd =
  fst status_cmd,
  Term.info "opam-user-setup" ~version:"0.6"

let () =
  match
    Term.eval_choice default_cmd [status_cmd; install_cmd; remove_cmd]
  with
  | `Error _ -> exit 1
  | _ -> exit 0
