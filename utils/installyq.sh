#!/usr/bin/env bash

VERSION=v4.9.3
BINARY=yq_linux_amd64

if ! [ -z ${1+x} ]
then
    VERSION=${1}
fi

if ! [ -z ${2+x} ]
then
    BINARY=${1}
fi

wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - |\
  tar xz && mv ${BINARY} /usr/bin/yq