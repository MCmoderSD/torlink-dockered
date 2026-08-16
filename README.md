A containerized wrapper around [torlink](https://github.com/baairon/torlink), the terminal torrent client.

Instead of installing Node and a global npm package on your machine, everything runs inside a container: the client, its WebTorrent engine, its state and its downloads. You attach to it from the outside, and it keeps itself up to date.

## Quick start

```bash
git clone https://github.com/MCmoderSD/torlink-dockered.git
```

```bash
cd torlink-dockered && docker compose up -d
```

```bash
./torlink.sh
```

The last command attaches you to the running client. Detach again with `Ctrl-b` then `d` — the container keeps seeding and downloading in the background.

Stop everything with:

```bash
docker compose down
```

## The `torlink` command

`torlink.sh` is a passthrough: whatever you give it is executed as `torlnk` inside the container, and the container is started first if it is not running yet.

```bash
./torlink.sh            # no arguments: attach to the running TUI
./torlink.sh help       # torlnk's own help
./torlink.sh version    # installed torlnk version
```

To use it as a normal command from anywhere, symlink it into your `PATH`:

```bash
sudo ln -s "$PWD/torlink.sh" /usr/local/bin/torlink
```

After that, `torlink` behaves like a locally installed `torlnk`:

```bash
torlink
```

The script resolves symlinks back to its own directory, so it always finds the `docker-compose.yaml` next to it, no matter where you call it from. It works with both `docker compose` and the older `docker-compose`.

Torrents are added from inside the TUI after attaching. Everything except `attach` starts a *second* `torlnk` process in the container, sharing the same config and download directory — fine for one-shots like `help` or `version`, but not a way to talk to the running engine.

`torlnk` also has headless modes (`watch <dir>`, `serve` on `:9161`, `files` on `:9160`). They are not wired up here: the container already runs the TUI, and no ports are published. Using them means publishing the port in `docker-compose.yaml` and running that mode as the container's command instead.

`torlnk update` is disabled — see [Updating](#updating).

## How it works

The container has no daemon. torlink's TUI process *is* the engine, so it has to stay alive:

1. The entrypoint installs `torlnk` from npm into the `/app` volume.
2. It seeds `/config/config/config.json` on first start, pointing the download directory at `/downloads`.
3. It starts `torlnk` inside a detached tmux session named `torlink`.
4. It waits for that session. When the session ends, the container exits.

`torlnk attach` inside the container is exactly `tmux new-session -A -s torlink`, so attaching from the host joins the same session that is doing the work.

## Updating

On every container start, the entrypoint installs the version requested by `TORLINK_VERSION` and reports whether it installed, updated or was already current. A restart is therefore an update:

```bash
docker compose restart
```

Pin a version by editing `docker-compose.yaml`:

```yaml
environment:
  TORLINK_VERSION: 1.2.3
```

If npm is unreachable at start, the container logs a warning and continues with the version already in the `/app` volume. It only fails hard if no working copy exists at all.

torlink's own updater is permanently disabled in the image (`TORLINK_NO_UPDATE_CHECK=1`, which suppresses the startup check and its banner). `torlnk update` shells out to `npm install -g torlnk@latest`, which cannot succeed anywhere: the transitive dependency `ip-set` has a `preinstall` hook (`npx only-allow pnpm`) that refuses npm outright. The local install used here is not affected, because npm does not run dependency preinstall scripts for local installs.

## Storage

Three named volumes:

| Volume             | Path         | Contents                          |
| ------------------ | ------------ | --------------------------------- |
| `torlink-downloads`| `/downloads` | finished and in-progress torrents |
| `torlink-config`   | `/config`    | config, torrent state, npm cache  |
| `torlink-app`      | `/app`       | the installed `torlnk` package    |

`torlnk` stores the download directory in its config file, not in an environment variable. To download into a folder on your host, replace the volume with a bind mount in `docker-compose.yaml`:

```yaml
volumes:
  - /srv/torrents:/downloads
```

The path inside the container must stay `/downloads`, otherwise the seeded config no longer matches.

## Sandbox

- read-only root filesystem, writes only into the volumes and a tmpfs `/tmp`
- runs as `1000:1000`, never as root
- `init: true`, so the reparented tmux server gets reaped properly
- no ports published to the host; the client only makes outbound connections
- the client, its Node runtime and every downloaded file stay inside the container

## Configuration

Everything is set directly in `docker-compose.yaml`. There is no `.env` file and no build section — images come from the registry.

| Variable          | Default            | Meaning                                |
| ----------------- | ------------------ | -------------------------------------- |
| `TORLINK_VERSION` | `latest`           | npm version range to install           |
| `TERM`            | `xterm-256color`   | terminal type for the TUI              |

## Known limits

- **Platforms:** `linux/amd64` and `linux/arm64` only. `node-datachannel` ships glibc prebuilds for these two; on other architectures the WebTorrent stack falls back to `webrtc-polyfill` and crashes on startup.
- **arm64:** the optional native helpers `utp-native`, `bufferutil` and `utf-8-validate` have no prebuilds. torlink runs fine without them, just with slower µTP and WebSocket paths.
- **glibc:** the image is Debian-based (`node:slim`), not Alpine, for the same prebuild reason.
- **First start** needs network access to npm, since the image ships no `torlnk` copy.

## Images

Published on every push to `main` for both platforms as a manifest list:

- **Docker Hub:** [`mcmodersd/torlink-dockered`](https://hub.docker.com/r/mcmodersd/torlink-dockered) — `docker.io/mcmodersd/torlink-dockered:latest`
- **GHCR:** [`MCmoderSD/torlink-dockered`](https://github.com/MCmoderSD/torlink-dockered/pkgs/container/torlink-dockered) — `ghcr.io/mcmodersd/torlink-dockered:latest`

`docker-compose.yaml` pulls from Docker Hub. To use GHCR instead, change the `image:` line:

```yaml
image: ghcr.io/mcmodersd/torlink-dockered:latest
```

## License

BSD 3-Clause. See [LICENSE](LICENSE).

torlink itself is a separate project — see [baairon/torlink](https://github.com/baairon/torlink).