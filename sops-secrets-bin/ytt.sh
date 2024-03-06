#!/usr/bin/env bash

# change file descriptors to prevent standard output pollution
exec 6>&1
exec 1>/dev/null

# restore file descriptors on exit
trap "exec 1>&6 6>&-" EXIT

YTT_OPTS=

VALUES_FILES=$(
for f in $(yq -P 'map(select(.name == "ytt-values-files")|.array[])|.[]' <<<"$ARGOCD_APP_PARAMETERS"); do
    [ -f $f ] && echo $f
    [ -d $f ] && find $f -mindepth 1 -maxdepth 1 -type f | sort
done
)

FILES_AS_VALUES=$(
for f in $(yq -P 'map(select(.name == "ytt-files-as-values")|.array[])|.[]' <<<"$ARGOCD_APP_PARAMETERS"); do
    [ -f $f ] && echo $f
    [ -d $f ] && find $f -mindepth 1 -maxdepth 1 -type f | sort
done
)

for f in $(yq -P 'map(select(.name == "ytt-files")|.array[])|.[]' <<<"$ARGOCD_APP_PARAMETERS"); do
[ -e $f ] && YTT_OPTS="$YTT_OPTS -f $f"
done

# save ytt-inlines into separate files
export INLINE_DIR=$(mktemp -d -p $TEMPDIR)
yq -P -s 'strenv(INLINE_DIR) + "/ytt-inline_" + $index' 'map(select(.name == "ytt-inlines")|.array[])|.[]' <<<"$ARGOCD_APP_PARAMETERS"
YTT_OPTS="$YTT_OPTS -f $INLINE_DIR"

# decrypt VALUES_FILES to named pipes
for f in $VALUES_FILES; do
nf=$(mktemp -p $TEMPDIR -u)
YTT_OPTS="$YTT_OPTS --data-values-file $nf"
if [[ "$(yq '.sops // ""' $f)" == "" ]]; then
    # file is not encrypted
    cp $f $nf
else
    # file is encrypted
    mkfifo $nf
    VALUE=$(sops-decrypt $f)
    cat <<<"$VALUE" > $nf &
fi
done

# decrypt FILES_AS_VALUES to named pipes
for f in $FILES_AS_VALUES; do
nf=$(mktemp -p $TEMPDIR -u)
key=$(basename $f | sed -r 's/[\._]/-/g')
YTT_OPTS="$YTT_OPTS --data-value-file $key=$nf"
if [[ "$(yq '.sops // ""' $f)" == "" ]]; then
    # file is not encrypted
    cp $f $nf
else
    # file is encrypted
    mkfifo $nf
    VALUE=$(sops-decrypt $f)
    cat <<<"$VALUE" > $nf &
fi
done

OVERRIDES=
for x in ${PARAM_OVERRIDES}; do
[ ! -z "$x" ] && OVERRIDES=$(yq $(envsubst <<<"$x") <<<"$OVERRIDES")
done

OVERRIDES_FILE=$(mktemp -p $TEMPDIR)
cat <<<"$OVERRIDES" > $OVERRIDES_FILE
YTT_OPTS="$YTT_OPTS --data-values-file $OVERRIDES_FILE"

ytt $YTT_OPTS >&6
