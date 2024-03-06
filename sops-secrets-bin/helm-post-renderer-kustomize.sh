#!/bin/bash

MANIFEST=$(mktemp -p .)
trap "rm $MANIFEST" EXIT

cat <&0 > $MANIFEST

KUSTOMIZE_FILE=
for f in kustomization.yaml kustomization.yml ; do
    [ -f $f ] && KUSTOMIZE_FILE=$f && break
done

[ -z "$KUSTOMIZE_FILE" ] && {
    KUSTOMIZE_FILE=kustomization.yaml
    log Creating KUSTOMIZE_FILE $KUSTOMIZE_FILE
    cat <<EOF >$KUSTOMIZE_FILE
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

EOF
}

log Using KUSTOMIZE_FILE $KUSTOMIZE_FILE

# add $MANIFEST to the top of the resources list
# followed by all the other YAML files in the current directory
# except $KUSTOMIZE_FILE

export RESOURCES="
$MANIFEST
$(find . -maxdepth 1 -mindepth 1 -regex '.*\.ya?ml$' -not -name $KUSTOMIZE_FILE | sort)
"

log Kustomize resources: $(tr '\n' ' ' <<<"$RESOURCES")

yq -i e '.resources|=(strenv(RESOURCES)|split("\n")|filter(. != ""))' $KUSTOMIZE_FILE

kustomize build
