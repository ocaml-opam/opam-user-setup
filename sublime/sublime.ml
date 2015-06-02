open OusSig
open OusTypes
open OusMisc

let name = "sublime3"

let config_dir = ".config" / "sublime-text-3"

let check () =
  has_command "sublime_text" && Sys.file_exists (home / config_dir)

let base_template = []

let base_setup = []

let pkg_files pkg =
  let srcdir = "share"/"sublime"/pkg in
  let files =
    try Array.to_list (Sys.readdir (opam_var "prefix" / srcdir))
    with Sys_error _ -> []
  in
  List.map
    (fun f -> srcdir/f, config_dir/"Packages"/pkg/f)
    files

let files = []

let comment = (^) "// "

module OcpIndex = struct
  let name = "ocp-index"
  let chunks = []
  let files = pkg_files "ocp-index"
  let post_install = []
  let pre_remove = []
end

let tools = [
  (module OcpIndex : ToolConfig)
]
