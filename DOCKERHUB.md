A containerized wrapper around [torlink](https://github.com/baairon/torlink), the terminal torrent client.

Instead of installing Node and a global npm package on your machine, everything runs inside this container: the client, its WebTorrent engine, its state and its downloads. You attach to it from the outside, and it keeps itself up to date.

**Source, issues and the `torlink` helper script: [github.com/MCmoderSD/torlink-dockered](https://github.com/MCmoderSD/torlink-dockered)**

## Tags

| Tag      | Platforms                    |
| -------- | ---------------------------- |
| `latest` | `linux/amd64`, `linux/arm64` |

Also published on GHCR as `ghcr.io/mcmodersd/torlink-dockered`.

## Quick start

```yaml
name: torlink-dockered

services:
  torlink-dockered:
    image: mcmodersd/torlink-dockered:latest
    container_name: torlink-dockered
    hostname: torlink-dockered
    pull_policy: always
    restart: on-failure
    user: "1000:1000"
    read_only: true
    init: true

    environment:
      TERM: xterm-256color
      TORLINK_VERSION: latest

    volumes:
      - downloads:/downloads
      - config:/config
      - app:/app

    tmpfs:
      - /tmp:mode=1777

    networks:
      - torlink-network

volumes:
  downloads:
    name: torlink-downloads
  config:
    name: torlink-config
  app:
    name: torlink-app

networks:
  torlink-network:
    name: torlink-network
```

```bash
docker compose up -d
```

Then attach to the client:

```bash
docker compose exec torlink-dockered screen -U -x torlink
```

Detach again with `Ctrl-a` then `d` — the container keeps seeding and downloading in the background. Torrents are added from inside the TUI.

The repository ships [`torlink.sh`](https://github.com/MCmoderSD/torlink-dockered/blob/master/torlink.sh), a wrapper you can symlink to `/usr/local/bin/torlink` so that plain `torlink` starts the container if needed and attaches.

## How it works

The container has no daemon. torlink's TUI process *is* the engine, so it has to stay alive:

1. The entrypoint installs `torlnk` from npm into the `/app` volume.
2. It seeds `/config/config/config.json` on first start, pointing the download directory at `/downloads`.
3. It starts `torlnk` inside a detached GNU screen session named `torlink`.
4. It waits for that session. When the session ends, the container exits.

Attaching with `screen -U -x torlink` joins that exact session, the one doing the work. `torlnk attach` is *not* used for this: upstream hardcodes it to `tmux new-session -A -s torlink`, and this image ships screen rather than tmux.

Session and attach both run in screen's forced UTF-8 mode, and the image sets `LANG`/`LC_ALL` to `C.UTF-8`. Without a UTF-8 locale a multiplexer downgrades the TUI's box-drawing and block glyphs to ASCII, which makes the interface look broken.

## Updating

On every container start the entrypoint installs the version requested by `TORLINK_VERSION`. A restart is therefore an update:

```bash
docker compose restart
```

Pin a version by setting `TORLINK_VERSION: 1.2.3`. If npm is unreachable, the container warns and keeps using the copy in the `/app` volume; it only fails hard when no working copy exists.

torlink's own update check is permanently disabled in the image. `torlnk update` shells out to `npm install -g torlnk@latest`, which cannot succeed anywhere: the transitive dependency `ip-set` has a `preinstall` hook (`npx only-allow pnpm`) that refuses npm outright.

## Environment

| Variable          | Default          | Meaning                      |
| ----------------- | ---------------- | ---------------------------- |
| `TORLINK_VERSION` | `latest`         | npm version range to install |
| `TERM`            | `xterm-256color` | terminal type for the TUI    |

## Volumes

| Path         | Contents                          |
| ------------ | --------------------------------- |
| `/downloads` | finished and in-progress torrents |
| `/config`    | config, torrent state, npm cache  |
| `/app`       | the installed `torlnk` package    |

`torlnk` stores the download directory in its config file, not in an environment variable, so a host folder has to be mounted at `/downloads` exactly:

```yaml
volumes:
  - /srv/torrents:/downloads
```

## Sandbox

- read-only root filesystem, writes only into the volumes and a tmpfs `/tmp`
- runs as `1000:1000`, never as root
- `init: true`, so the reparented screen server gets reaped properly
- no ports published; the client only makes outbound connections
- the client, its Node runtime and every downloaded file stay inside the container

## Known limits

- **Platforms:** `linux/amd64` and `linux/arm64` only. `node-datachannel` ships glibc prebuilds for these two; elsewhere the WebTorrent stack falls back to `webrtc-polyfill` and crashes on startup.
- **arm64:** the optional native helpers `utp-native`, `bufferutil` and `utf-8-validate` have no prebuilds. torlink runs fine without them, just with slower µTP and WebSocket paths.
- **glibc:** the image is Debian-based (`node:slim`), not Alpine, for the same prebuild reason.
- **First start** needs network access to npm, since the image ships no `torlnk` copy.

## License

BSD 3-Clause. See [LICENSE](https://github.com/MCmoderSD/torlink-dockered/blob/master/LICENSE).

torlink itself is a separate project — see [baairon/torlink](https://github.com/baairon/torlink).
