# opam-user-setup

Simplify user setup for various editors to OCaml users.

This tool is designed to be installed as an OPAM package, with optional
dependencies on various helper tools like ocp-indent, Merlin, or ocp-index. Its
goal is to automate the configuration and update of various editors for basic
OCaml usage and for these tools.


### Usage

#### As an OPAM package

`opam install user-setup` detects editors installed on the system and tools
installed in OPAM, installs a base template for configuring the editors if no
configuration was present, and adds snippets in each editor's configuration for
binding with the tools. Any change in the installed tools will re-run
`user-setup` to maintain the setup up-to-date. Basic configuration for the OCaml
toplevel is also included.

The snippets are watermarked, so that they are left as-is once the user makes
modifications.

**Limitations**:
- if you install a new editor, you'll need to `opam reinstall user-setup`
  manually
- removing the OPAM package won't work remove the setup at the moment, you'll
  need to `opam-user-setup --remove` by hand. There is no way in OPAM to tell
  removal as the first step of a reinstallation from final removal at the
  moment, and removing the snippets each time would break proper update.

#### Directly

```
opam-user-setup [tuareg] [ocp-indent] [merlin] [ocp-index]
```

Installs the base template for all detected editors, if no configuration file is
present, and the snippets configuring the given tools.


### Support matrix

This should reflect the current state of support for editors and tools. More may
be added.

|editor |base template|ocaml|ocp-indent|merlin|ocp-index|
|-------|-------------|-----|----------|------|---------|
|emacs  |yes          |yes  |yes       |yes   |yes      |
|vim    |needs review |yes  |yes       |yes   |yes      |
|gedit  |planned      |     |          |      |         |
|sublime|planned      |     |          |      |         |
|eclipse|planned      |     |          |      |         |


### Design

#### General layout

The tiny core lies in the modules `OusMisc`, `OusSig`, `OusTypes` and `OusMain`
at the root of the project. The important stuff is in a separate directory for
each editor: `emacs`, `vim`, `gedit`, `sublime` and `ocamltop`. In each case, it
contains a module satisfying the `OusSig.EditorConfig` signature, which exposes
some functions specific to the editor (checking, comment syntax...), a full
configuration file template, general configuration file setup and specific
configuration for each tool.

Editor modules are then referenced in the list `OusMain.editors`.

#### Editor support

* The base template (`Editor.base_template`) for the editor should be a basic
  configuration with good defaults, and a non-OPAM, or even OCaml specific setup
  (not unlike the rationale behind
  [vim-sensible](https://github.com/tpope/vim-sensible)).
* OCaml or OPAM specific configuration (OPAM environment, basic OCaml mode
  setup) should be put in the base setup (`Editor.base_setup`). In a scenario
  where a user already used the editor but not OCaml, this is what would need to
  be added.
* Tool configuration should be **also** added to `Editor.base_setup`, with a
  *dynamic* detection of the tool, whenever possible.
* Tool snippets should be added when:
  - dynamic detection of the tool is not possible (configuration language not
    advanced enough)
  - the tool can be used from switches other than the one it was installed in,
    in this case specifying a static path here may help find it. This is the
    case for ocp-indent, for example.

This is a community effort, and contributions are gladly welcome.


### License

The tool itself is released under ISC, but the included configuration templates
and snippets themselves are in CC0 (almost public domain) -- because who wants a
license on his configuration files ?
