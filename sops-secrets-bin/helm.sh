#!/usr/bin/env bash

# change file descriptors to prevent standard output pollution
exec 6>&1
exec 1>/dev/null

# restore file descriptors on exit
trap "exec 1>&6 6>&-" EXIT

log "Helm chart: ${PARAM_HELM_REPO}/${PARAM_HELM_CHART}
Helm chart version: ${PARAM_HELM_VERSION}
Helm release: ${PARAM_ID}"

HELM_OPTS="--include-crds"
POST_RENDERER_KUSTOMIZE_SCRIPT=$(realpath $(dirname $0)/helm-post-renderer-kustomize.sh)
log $(ls -l $POST_RENDERER_KUSTOMIZE_SCRIPT)

[ ! -x "$POST_RENDERER_KUSTOMIZE_SCRIPT" ] && POST_RENDERER_KUSTOMIZE_SCRIPT=

log POST_RENDERER_KUSTOMIZE_SCRIPT=$POST_RENDERER_KUSTOMIZE_SCRIPT

# KUBE_API_VERSIONS is a comma-separated list of API versions available in the target cluster
IFS=, read -ra APIS <<<"$KUBE_API_VERSIONS"
for API in "${APIS[@]}"; do
    HELM_OPTS="$HELM_OPTS --api-versions $API";
done

VALUE_FILES=$(
for f in $(yq -P 'map(select(.name == "helm-value-files")|.array[])|.[]' <<<"$ARGOCD_APP_PARAMETERS"); do
    [ -f $f ] && echo $f
    [ -d $f ] && find $f -mindepth 1 -maxdepth 1 -type f | sort
done
)

POST_RENDERER_KUSTOMIZE_FILES=$(
for f in $(yq -P 'map(select(.name == "helm-post-renderer-kustomize-files")|.array[])|.[]' <<<"$ARGOCD_APP_PARAMETERS"); do
    [ -f $f ] && echo $f
    [ -d $f ] && find $f -mindepth 1 -maxdepth 1 -type f | sort
done
)

# decrypt files to named pipes
for f in $VALUE_FILES; do
    nf=$(mktemp -p $TEMPDIR -u)
    HELM_OPTS="$HELM_OPTS --values $nf"
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
HELM_OPTS="$HELM_OPTS --values $OVERRIDES_FILE"

if [[ "$POST_RENDERER_KUSTOMIZE_FILES" != "" && "$POST_RENDERER_KUSTOMIZE_SCRIPT" != "" ]]; then
    # prepare the temporary kustomize directory
    KUSTOMIZE_DIR=$(mktemp -d)
    for f in $POST_RENDERER_KUSTOMIZE_FILES; do
        cp $f $KUSTOMIZE_DIR
    done
    HELM_OPTS="$HELM_OPTS --post-renderer $POST_RENDERER_KUSTOMIZE_SCRIPT"
    cd $KUSTOMIZE_DIR
fi

log HELM_OPTS=$HELM_OPTS

helm template ${PARAM_ID} ${PARAM_HELM_REPO}/${PARAM_HELM_CHART} --version ${PARAM_HELM_VERSION} --namespace ${PARAM_HELM_NAMESPACE} ${HELM_OPTS} >&6
