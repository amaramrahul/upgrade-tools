# upgrade-tools

Small scripts that keep self-hosted software up to date, meant to run unattended from cron.

| Tool | What it does |
|---|---|
| [docker-container-upgrade](#docker-container-upgrade) | Keeps a Docker container on the newest version tag of its image |

## Installing

Clone the repo to `/opt/upgrade-tools`:

```bash
sudo git clone https://github.com/amaramrahul/upgrade-tools.git /opt/upgrade-tools
```

To update the tools later, run `sudo git -C /opt/upgrade-tools pull`. Each tool lists its own requirements below.

## docker-container-upgrade

Checks the image's registry for a newer version tag, then pulls it and recreates the container with the same `docker run` options.

**Requires:** bash 4.4+, docker, skopeo and jq (`sudo apt install skopeo jq`).

### Usage

```
docker-container-upgrade --name <container> --repo <repo> [--minor-only] [--dry-run] [-- <docker run args>]
```

The container is recreated with:

```
docker run -d --name=<container> --restart unless-stopped <docker run args> <repo>:<version>
```

- **Versions:** only tags made of three or more numbers count (`1.12.2`, `8.2.7.0`, `2026.11.2`). Tags such as `latest`, `stable`, `1.13` and `1.13.0-rc1` are ignored.
- **`--minor-only`:** minor and patch upgrades are installed. A new major version (first number) is reported but not installed.
- **Missing container:** it's created from the newest version. A container running on a tag like `latest` is moved to the newest version tag.
- **No rollback:** if the new container fails to start, the script exits with an error and the service stays down.

| Exit status | Meaning |
|---|---|
| 0 | No upgrade found |
| 1 | Error |
| 2 | Upgrade done (or, with `--dry-run`, would be done) |
| 3 | Upgrade blocked (major version with `--minor-only`) |

Example daily cron job, saved as `/etc/cron.daily/x-homeassistant-upgrade` (cron.daily skips file names that contain a dot):

```bash
#!/usr/bin/env bash
exec cronic /opt/upgrade-tools/docker-container-upgrade --name homeassistant --repo ghcr.io/home-assistant/home-assistant --minor-only -- \
    --net=host \
    --privileged \
    -e TZ=Asia/Kolkata \
    -v /usr/local/home-assistant:/config
```

[`cronic`](https://habilis.net/cronic/) (`sudo apt install cronic`) hides the output when the exit status is 0 and nothing was written to stderr, so cron only emails you when there's an upgrade or an error.

### Testing

Add `--dry-run` to see what would happen without changing anything:

```bash
/opt/upgrade-tools/docker-container-upgrade --name homeassistant --repo ghcr.io/home-assistant/home-assistant --minor-only --dry-run
```
