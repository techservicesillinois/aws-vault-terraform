FROM debian:stretch

COPY docker-entrypoint.sh /usr/local/bin/

RUN set -xe \
    && apt-get update && apt-get install -y \
        libltdl7 \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-yaml \
        jq \
        --no-install-recommends \
    && pip3 install awscli \
    && chmod a+rx /usr/local/bin/docker-entrypoint.sh \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
