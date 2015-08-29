all: opam-user-setup user-setup.install

opam-user-setup: _build/ousMain.native
	@cp $< $@

.PHONY: ALWAYS
ALWAYS:

_build/ousMain.native: ALWAYS
	ocamlbuild -r -I . -Is ocamltop,emacs,vim,sublime,gedit -use-ocamlfind -tag debug -pkgs unix,re,re.pcre,cmdliner ousMain.native

user-setup.install: ALWAYS
	echo 'bin: "opam-user-setup"' > $@
	echo 'share-root: [' >> $@
	for f in sublime/files/ocp-index/*; do \
	  echo "  \"$$f\" { \"sublime/ocp-index/$$(basename $$f)\" }"; \
	done >> $@
	echo ']' >> $@
