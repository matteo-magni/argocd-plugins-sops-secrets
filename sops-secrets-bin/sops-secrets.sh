#!/usr/bin/env bash

log() {
    echo "$(date): $*" >&2
}

export TEMPDIR=$(mktemp -d)
trap "rm -rf $TEMPDIR" EXIT

CWD=$(realpath $(dirname $0))

if [[ "${PARAM_MODE}" == "helm" ]]; then

    ${CWD}/helm.sh

elif [[ "${PARAM_MODE}" == "ytt" ]]; then
    # this is a ytt templated directory
    # expecting a ./config directory with ytt-templated files
    # and optionally a list of locations for value files, meaning either actual files or directories

    ${CWD}/ytt.sh

elif [ -f kustomization.yaml ]; then
    # this is a kustomize directory

    ${CWD}/kustomize.sh

else
    # this is plain YAMLs
    # merge them all and split the documents into single files
    # if a document is sops-encrypted in a multi-document file, sops cannot decrypt it

    ${CWD}/plain.sh

fi