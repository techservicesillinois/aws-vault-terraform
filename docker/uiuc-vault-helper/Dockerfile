FROM debian:stretch

COPY docker-entrypoint.sh /usr/local/bin/
COPY incommon.pem /etc/ssl/

RUN set -xe \
    && apt-get update && apt-get install -y \
        python3 \
        python3-pip \
        python3-yaml \
        jq \
        --no-install-recommends \
    && pip3 install awscli \
    && chmod a+rx /usr/local/bin/docker-entrypoint.sh \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
