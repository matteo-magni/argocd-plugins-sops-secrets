#!/usr/bin/env bash

# change file descriptors to prevent standard output pollution
exec 6>&1
exec 1>/dev/null

# restore file descriptors on exit
trap "exec 1>&6 6>&-" EXIT

CWD=$(pwd)
pushd $TEMPDIR

# build original files structure with named pipes
find $CWD -mindepth 1 -type d | while read f; do mkdir -p $(realpath --relative-to $CWD $f); done
find $CWD -type f | while read f; do
    nf=$(realpath --relative-to $CWD $f)
    if [[ "$(yq '.sops // ""' $f)" == "" ]]; then
        # file is not encrypted
        cp $f $nf
    else
        # file is encrypted
        mkfifo $nf

        # sops-decrypt is time-consuming
        # so I make sure that it's completed before using its output in a background process
        VALUE=$(sops-decrypt $f)
        cat <<<"$VALUE" > $nf &
    fi
done
sleep 1
kustomize build >&6
popd
