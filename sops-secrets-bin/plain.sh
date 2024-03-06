#!/usr/bin/env bash

# change file descriptors to prevent standard output pollution
exec 6>&1
exec 1>/dev/null

# restore file descriptors on exit
trap "exec 1>&6 6>&-" EXIT

CWD=$(pwd)
pushd $TEMPDIR
find $CWD -maxdepth 1 -mindepth 1 -type f -iregex '.*\.ya?ml' | xargs -r yq ea . | yq -s '"file_" + $index' -
{
for f in $(ls -1); do
    echo "---"
    sops-decrypt $f
done
} >&6
popd
