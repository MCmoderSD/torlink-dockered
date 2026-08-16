FROM node:slim

RUN apt update && apt install -y --no-install-recommends \
        screen ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG WITH_BUILD_TOOLS=0
RUN if [ "$WITH_BUILD_TOOLS" = "1" ]; then \
        apt update && apt install -y --no-install-recommends \
            build-essential python3 \
        && rm -rf /var/lib/apt/lists/*; \
    fi

RUN if [ "$WITH_BUILD_TOOLS" != "1" ]; then \
        rm -rf /usr/local/include/node; \
    fi \
    && rm -rf /usr/local/share/doc /usr/local/share/man

RUN printf '#!/bin/sh\nexec node /app/node_modules/torlnk/dist/cli.cjs "$@"\n' \
        > /usr/local/bin/torlnk \
    && chmod 755 /usr/local/bin/torlnk

COPY entrypoint.sh /usr/local/bin/torlink-entrypoint
RUN chmod 755 /usr/local/bin/torlink-entrypoint

ENV TORLINK_DOWNLOAD_DIR=/downloads \
    TORLINK_STATE_DIR=/config \
    TORLINK_APP_DIR=/app \
    HOME=/config/home \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    SCREENDIR=/tmp/screen \
    npm_config_cache=/config/npm-cache

ENV TORLINK_VERSION=latest
ENV TORLINK_AUTO_UPDATE=1
ENV TORLINK_NO_UPDATE_CHECK=1

RUN mkdir -p /config /downloads /app \
    && chown -R node:node /config /downloads /app \
    && chmod 0777 /config /downloads /app

USER node
VOLUME ["/config", "/downloads", "/app"]

ENTRYPOINT ["/usr/local/bin/torlink-entrypoint"]