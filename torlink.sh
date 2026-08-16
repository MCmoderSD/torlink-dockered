#!/bin/sh
set -eu

SELF="$0"
while [ -L "$SELF" ]; do
    LINK="$(readlink "$SELF")"
    case "$LINK" in
        /*) SELF="$LINK" ;;
        *) SELF="$(dirname "$SELF")/$LINK" ;;
    esac
done
cd "$(dirname "$SELF")"

SERVICE=torlink-dockered

if docker compose version >/dev/null 2>&1; then
    dc() { docker compose "$@"; }
elif command -v docker-compose >/dev/null 2>&1; then
    dc() { docker-compose "$@"; }
else
    echo "torlink: needs docker compose (or docker-compose)" >&2
    exit 1
fi

if [ -z "$(dc ps --status running -q "$SERVICE" 2>/dev/null)" ]; then
    if ! dc up -d >&2; then
        echo "torlink: could not start the container." >&2
        echo "         Images come from the registry only, there is no local build." >&2
        echo "         Check that the image in docker-compose.yaml has been published." >&2
        exit 1
    fi
fi

if [ "$#" -eq 0 ]; then
    set -- attach
fi

if [ -t 0 ]; then
    dc exec "$SERVICE" torlnk "$@"
else
    dc exec -T "$SERVICE" torlnk "$@"
fi