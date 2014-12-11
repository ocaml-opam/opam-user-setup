# opam-user-setup

Simplify user setup for various editors to OCaml users.

This tool is designed to be installed as an OPAM package, with optional
dependencies on various helper tools like ocp-indent, Merlin, or ocp-index. Its
goal is to automate the configuration and update of various editors for basic
OCaml usage and for these tools.

This is a very early version. It only implements configuration for emacs and
ocp-indent, Merlin, ocp-index. This version takes as arguments the list of tools
you want to configure. It _will_ modify your `.emacs`, but not in a destructive
way.
