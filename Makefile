all: opam-user-setup user-setup.install

opam-user-setup: _build/ousMain.native
	@cp $< $@

.PHONY: ALWAYS
ALWAYS:

NEEDPP != ocaml -vnum | awk -F. '{if ($$1<4 || ($$1==4 && $$2<=1)) print "yes"}'
ifeq ($(NEEDPP),yes)
  PP = -pp $(shell pwd)/pp_401.ml
endif

PACKAGES = unix re re.pcre cmdliner

SUBDIRS = ocamltop emacs vim sublime gedit

_build/ousMain.native: ALWAYS
	ocamlbuild -r \
	  -tag debug \
	  -I . $(patsubst %,-I %,$(SUBDIRS)) \
	  -use-ocamlfind $(patsubst %,-pkg %,$(PACKAGES)) \
	  $(PP) \
	  ousMain.native

user-setup.install: ALWAYS
	echo 'bin: "opam-user-setup"' > $@
	echo 'share-root: [' >> $@
	for f in sublime/files/ocp-index/*; do \
	  echo "  \"$$f\" { \"sublime/ocp-index/$$(basename $$f)\" }"; \
	done >> $@
	echo ']' >> $@
