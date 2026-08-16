#!/bin/sh
set -eu

SESSION=torlink
CONFIG_DIR="${TORLINK_STATE_DIR:-/config}"
DOWNLOAD_DIR="${TORLINK_DOWNLOAD_DIR:-/downloads}"
APP_DIR="${TORLINK_APP_DIR:-/app}"
WANT_VERSION="${TORLINK_VERSION:-latest}"
AUTO_UPDATE="${TORLINK_AUTO_UPDATE:-1}"
CONFIG_FILE="$CONFIG_DIR/config/config.json"
SCREEN_DIR="${SCREENDIR:-/tmp/screen}"

log() { echo "[torlink] $*"; }

has_session() {
    screen -ls 2>/dev/null \
        | sed -n "s/^[[:space:]]*\([0-9][0-9]*\)\.$SESSION[[:space:]].*/\1/p" \
        | grep -q .
}

installed_version() {
    node -p "require('$APP_DIR/node_modules/torlnk/package.json').version" 2>/dev/null || true
}

update_torlnk() {
    before="$(installed_version)"

    if [ ! -f "$APP_DIR/package.json" ]; then
        (cd "$APP_DIR" && npm init -y >/dev/null 2>&1) || true
    fi

    log "checking npm for torlnk@${WANT_VERSION}${before:+ (installed: $before)}"
    if npm install --prefix "$APP_DIR" --omit=dev --no-audit --no-fund \
            --loglevel=error "torlnk@${WANT_VERSION}" >/tmp/npm-install.log 2>&1; then
        sed 's/^/[npm] /' /tmp/npm-install.log
        after="$(installed_version)"
        if [ -z "$before" ]; then
            log "installed torlnk $after"
        elif [ "$before" != "$after" ]; then
            log "updated torlnk $before -> $after"
        else
            log "torlnk $after is current"
        fi
    else
        sed 's/^/[npm] /' /tmp/npm-install.log
        log "WARNING: update failed (offline? npm down?)"
    fi
    rm -f /tmp/npm-install.log
}

mkdir -p "$CONFIG_DIR/config" "$CONFIG_DIR/data" "$CONFIG_DIR/home" "$APP_DIR" "$DOWNLOAD_DIR"
mkdir -p "$SCREEN_DIR"
chmod 700 "$SCREEN_DIR"

if [ "$AUTO_UPDATE" != "0" ]; then
    update_torlnk
else
    log "auto-update off, using torlnk $(installed_version)"
fi

if [ ! -f "$APP_DIR/node_modules/torlnk/dist/cli.cjs" ]; then
    log "ERROR: no torlnk in $APP_DIR and the install did not succeed."
    log "       Check the container's network access, then start it again."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    printf '{"downloadDir":"%s","trackers":[]}\n' "$DOWNLOAD_DIR" > "$CONFIG_FILE"
fi

shutdown() {
    if has_session; then
        screen -S "$SESSION" -X stuff "$(printf '\003')" >/dev/null 2>&1 || true
        i=0
        while [ "$i" -lt 5 ] && has_session; do
            sleep 1
            i=$((i + 1))
        done
    fi
    screen -S "$SESSION" -X quit >/dev/null 2>&1 || true
    exit 0
}
trap shutdown TERM INT

if [ "${1:-}" = "run-once" ]; then
    shift
    exec torlnk "$@"
fi

log "starting torlnk $(installed_version) - attach with: docker compose exec torlink-dockered screen -U -x $SESSION"
screen -U -dmS "$SESSION" torlnk

i=0
while [ "$i" -lt 10 ] && ! has_session; do
    sleep 1 &
    wait $!
    i=$((i + 1))
done

while has_session; do
    sleep 2 &
    wait $!
done