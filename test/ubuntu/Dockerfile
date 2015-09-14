FROM ubuntu:vivid
MAINTAINER Louis Gesbert <louis.gesbert@ocamlpro.com>
ENV APT_PACKAGES \
  ocaml-nox \
  camlp4-extra \
  ocaml-native-compilers \
  emacs-nox \
  vim-nox \
  packup \
  unzip \
  git \
  curl \
  patch \
  make \
  sudo \
  rsync \
  apt-utils
RUN apt-get update && \
    apt-get install -d -y --no-install-recommends $APT_PACKAGES
RUN apt-get install -y --no-install-recommends $APT_PACKAGES
RUN curl -L https://github.com/ocaml/opam/releases/download/1.2.2/opam-1.2.2-x86_64-Linux -o /usr/bin/opam && chmod a+x /usr/bin/opam
RUN useradd -d /home/test -m -s /bin/bash test && passwd -l test
RUN echo "test ALL=NOPASSWD: /usr/bin/apt-get install *" >>/etc/sudoers
USER test
WORKDIR /home/test
ENV HOME /home/test
ENV OPAMYES true
RUN opam init -a
RUN opam depext -i merlin ocp-indent ocp-index tuareg
COPY . /home/test/ous
USER root
RUN chown -R test ous
USER test
ENV OPAMVERBOSE 1
ENV OCAMLRUNPARAM b
RUN opam pin add user-setup ous/
RUN opam user-setup install
RUN cd ous && opam config exec -- make
