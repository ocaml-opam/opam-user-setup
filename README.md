# opam-user-setup

Simplify user setup for various editors to OCaml users.

This tool knows about several editors, and several OCaml editing tools existing
as opam packages. It automates the configuration of these editors, providing
base templates when appropriate, and suitably installing the editing tools in
the editor's configuration.

For example, it will configure your emacs or Vim to indent OCaml files using
[ocp-indent](http://www.typerex.org/ocp-indent.html) if you have that installed.

Opam-user-setup is designed to be suitable both to beginners not wanting to be
bothered with configuration files and to people who manage them carefully. It's
customisable and reversible.

Support for different editors or tools is open, feel free to request or
contribute!

### Usage

A working opam installation and OCaml 4.02.0 or newer are required. If you have
opam >= 1.2, installation and setup are just one command away:

```
opam user-setup install
```

If you use multiple opam
["switches"](http://opam.ocaml.org/doc/FAQ.html#Whatisaquotswitchquot), make
sure to run this from one where all the editing tools you want are installed.

On earlier opam versions:

```
opam install user-setup
opam-user-setup install
```

Opam will remind you to re-run the command if some tools have changed. You can
safely re-run it too if you install a new editor, for example. Changes to your
configuration files are watermarked, can be safely removed, and won't be changed
once you manually modify them.

For more, see

```
opam-user-setup --help
```

Without argument, the current setup status will be checked and printed.

### Support matrix

This should reflect the current state of support for editors and tools. More may
be added.

|editor |base template|ocaml   |ocp-indent|merlin|ocp-index|
|-------|-------------|--------|----------|------|---------|
|emacs  |yes          |yes     |yes       |yes   |yes      |
|vim    |yes          |yes     |yes       |yes   |yes      |
|sublime|no           |built-in|no        |no    |yes      |
|gedit  |not yet      |        |          |      |         |
|eclipse|not yet      |        |          |      |         |

Current support in emacs and vim (only) is dynamic, which means that the editor
will adapt to the current opam switch when run (using e.g. merlin only when
available in the switch, but e.g. ocp-indent from the base switch if unavailable
-- as they have different ocaml version compatibility requirements).

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
  *dynamic* detection of the tool -- using opam -- whenever possible.
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

Notable exceptions are with the Vim base template, which is taken from
[vim-sensible](https://github.com/tpope/vim-sensible) by Tim Pope, and the
sublime-text ocp-index plugin, taken from
[sublime-ocp-index](https://github.com/whitequark/sublime-ocp-index) by Peter
Zotov. See the LICENSE file for details.
