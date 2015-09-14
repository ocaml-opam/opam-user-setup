all: test

test: ubuntu

ubuntu-container.tag: ubuntu/Dockerfile ../opam-user-setup
	rm -f $@
	docker build -f ubuntu/Dockerfile -t user-setup-test-ubuntu ..
	touch $@

.PHONY: ubuntu
ubuntu: ubuntu-container.tag
	docker run user-setup-test-ubuntu bash -c \
	  "cd ous && \
	   emacs --batch -l ~/.emacs ousMain.ml \
             --eval '(search-forward \"opam_var\")' \
	     --eval '(merlin-type-enclosing)'" \
	  2>&1 | tail -n1 | { read out; test "$$out" = "string -> 'a"; }
