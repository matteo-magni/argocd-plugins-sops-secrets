FROM viaductoss/ksops:v4.2.5

LABEL "org.opencontainers.image.title"="argocd-plugins-sops-secrets"

ARG HELM_RELEASE=v3.13.1
ARG YQ_RELEASE=v4.35.2
ARG SOPS_RELEASE=v3.8.1
ARG YTT_RELEASE=v0.46.0

USER 0

RUN useradd -u 999 -d /home/argocd -m argocd
RUN apt update && apt install -y curl gettext
RUN curl -sSfL https://get.helm.sh/helm-${HELM_RELEASE}-linux-amd64.tar.gz | tar -C /usr/local/bin/ --strip-components 1 -xzf - linux-amd64/helm && \
    curl -sSfLo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/${YQ_RELEASE}/yq_linux_amd64 && \
    curl -sSfLo /usr/local/bin/sops https://github.com/getsops/sops/releases/download/${SOPS_RELEASE}/sops-${SOPS_RELEASE}.linux.amd64 && \
    curl -sSfLo /usr/local/bin/ytt https://github.com/carvel-dev/ytt/releases/download/${YTT_RELEASE}/ytt-linux-amd64

COPY --link bin /usr/local/bin/
COPY --link sops-secrets-bin /sops-secrets-bin/

RUN chmod -R a+x /usr/local/bin/ /sops-secrets-bin/

USER 999

WORKDIR /home/argocd

ENTRYPOINT [ "bash" ]
