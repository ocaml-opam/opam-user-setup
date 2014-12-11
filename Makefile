all: opam-user-setup

opam-user-setup: _build/ousMain.native
	@cp $< $@

.PHONY: ALWAYS
ALWAYS:

_build/ousMain.native: ALWAYS
	ocamlbuild -r -I . -I emacs -I vim -use-ocamlfind -tag debug -pkgs unix,re,re.pcre ousMain.native
