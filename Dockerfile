FROM debian:stable-slim

# Based on https://github.com/wshito/roswell-base

# openssl-dev is needed for Quicklisp
# perl is needed for ACL2's certification scripts
# wget is needed for downloading some files while building the docker image
# The rest are needed for Roswell

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        automake \
        autoconf \
        libcurl4-openssl-dev \
        ca-certificates \
        libssl-dev \
        wget \
        perl \
        sbcl \
        zlib1g-dev \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/* # remove cached apt files

RUN mkdir /root/sbcl \
    && cd /root \
    && wget "http://prdownloads.sourceforge.net/sbcl/sbcl-2.0.3-source.tar.bz2?download" -O sbcl.tar.bz2 -q \
    && tar -xjf sbcl.tar.bz2 \
    && rm sbcl.tar.bz2 \
    && cd sbcl-2.0.3 \
    && sh make.sh --without-immobile-space --without-immobile-code --without-compact-instance-header --fancy --dynamic-space-size=4Gb \
    && apt-get remove -y sbcl \
    && sh install.sh

ADD fix-quicklisp.pl /tmp/

RUN cd /tmp && \
    curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp --quit --eval '(quicklisp-quickstart:install)' &&\
    perl /tmp/fix-quicklisp.pl &&\
    sbcl --eval '(load "/root/quicklisp/setup.lisp")' --eval "(ql:add-to-init-file)"

RUN git clone --depth 1 -b 8.3 git://github.com/acl2/acl2.git /root/acl2

ARG ACL2_BUILD_OPTS=""
ARG ACL2_CERTIFY_OPTS="-j 4"
ARG ACL2_CERTIFY_TARGETS="basic"

RUN cd /root/acl2 \
    && make LISP="sbcl" $ACL2_BUILD_OPTS \
    && cd books \
    && make $ACL2_CERTIFY_TARGETS ACL2=/root/acl2/saved_acl2 $ACL2_CERTIFY_OPTS

RUN apt-get remove -y \
    build-essential \
    git \
    automake \
    autoconf \
    unzip \
    && apt-get install -y --no-install-recommends make \
    && apt-get autoremove -y

RUN mkdir -p /opt/acl2/bin \
    && ln -s /root/acl2/saved_acl2 /opt/acl2/bin/acl2 \
    && ln -s /root/acl2/books/build/cert.pl /opt/acl2/bin/cert.pl \
    && ln -s /root/acl2/books/build/clean.pl /opt/acl2/bin/clean.pl \
    && ln -s /root/acl2/books/build/critpath.pl /opt/acl2/bin/critpath.pl

ENV PATH="/opt/acl2/bin:${PATH}"
ENV ACL2_SYSTEM_BOOKS="/root/acl2/books"
ENV ACL2="/root/acl2/saved_acl2"

CMD ["/root/acl2/saved_acl2"]
