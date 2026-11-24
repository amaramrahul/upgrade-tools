# upgrade-tools

Small scripts that keep self-hosted software up to date, meant to run unattended from cron.

| Tool | What it does |
|---|---|
| [docker-container-upgrade](#docker-container-upgrade) | Keeps a Docker container on the newest version tag of its image |
| [openwrt-upgrade-check](#openwrt-upgrade-check) | Reports when a router runs an older OpenWrt than the newest GitHub release |

| [gear-lever-appimage-upgrade](#gear-lever-appimage-upgrade) | Updates the AppImages managed by Gear Lever |

## Installing

Clone the repo anywhere, then run the installer, which asks which tools to install into `/usr/local/bin`:

```bash
git clone https://github.com/amaramrahul/upgrade-tools.git
cd upgrade-tools
sudo ./install.sh
```

To remove tools, run `sudo ./install.sh --uninstall`; it asks which ones. To update, run `git pull` and then `sudo ./install.sh` again. Set `PREFIX` (default `/usr/local`) or `DESTDIR` to install elsewhere. Each tool lists its own requirements below.

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
- **Stopped container:** a container that exists but isn't running (stopped, paused, ...) is left alone: not started, not upgraded. The script logs it and exits 4, so cron mails you on every run while the container stays down. It's upgraded again on the first run after you start it.
- **No rollback:** if the new container fails to start, the script exits with an error and the service stays down.

| Exit status | Meaning |
|---|---|
| 0 | No upgrade found |
| 1 | Error |
| 2 | Upgrade done (or, with `--dry-run`, would be done) |
| 3 | Upgrade blocked (major version with `--minor-only`) |
| 4 | Container exists but isn't running (left alone) |

Example daily cron job, saved as `/etc/cron.daily/x-homeassistant-upgrade` (cron.daily skips file names that contain a dot):

```bash
#!/usr/bin/env bash
exec chronic -e docker-container-upgrade --name homeassistant --repo ghcr.io/home-assistant/home-assistant --minor-only -- \
    --net=host \
    --privileged \
    -e TZ=Asia/Kolkata \
    -v /usr/local/home-assistant:/config
```

[`chronic`](https://joeyh.name/code/moreutils/) (`sudo apt install moreutils`) hides the output unless the exit status is non-zero or, with `-e`, something was written to stderr. So cron only emails you when there's an upgrade or an error. To upgrade several containers from one cron job, add one `chronic -e` line per container, without `exec`.

### Testing

Add `--dry-run` to see what would happen without changing anything:

```bash
docker-container-upgrade --name homeassistant --repo ghcr.io/home-assistant/home-assistant --minor-only --dry-run
```

## openwrt-upgrade-check

Compares the OpenWrt version installed on a router with the newest release on GitHub. It only reports; it never upgrades the router.

**Requires:** bash, git and ssh (`sudo apt install openssh-client`). The router must accept key-based ssh login for the user (default `root`) from the machine running the script.

### Usage

```
openwrt-upgrade-check --host <host> [--user <user>] [--identity <file>]
```

- **Newest release:** the highest `vX.Y.Z` tag of [openwrt/openwrt](https://github.com/openwrt/openwrt). Release candidates are ignored.
- **`--identity`:** ssh private key to log in with. Only this key is tried; ssh's default keys and the agent are not.
- **First connection:** the router's host key is stored automatically the first time. A changed host key is rejected.
- **Installed version:** `DISTRIB_RELEASE` from `/etc/openwrt_release` on the router.

| Exit status | Meaning |
|---|---|
| 0 | Router is up to date |
| 1 | Error (for example the router is unreachable) |
| 2 | Upgrade available |

**Locking the key down:** the only command the script runs on the router is `cat /etc/openwrt_release`. To stop the key from running anything else, create a dedicated key (`ssh-keygen -t ed25519 -f ~/.ssh/openwrt-upgrade-check`) and add it to `/etc/dropbear/authorized_keys` on the router with a forced command:

```
command="cat /etc/openwrt_release",restrict ssh-ed25519 AAAA... openwrt-upgrade-check
```

Then pass `--identity ~/.ssh/openwrt-upgrade-check`.

Example daily cron job, saved as `/etc/cron.daily/x-openwrt-upgrade-check`:

```bash
#!/usr/bin/env bash
exec chronic -e openwrt-upgrade-check --host 192.168.1.1 --identity /root/.ssh/openwrt-upgrade-check
```

To check several routers from one cron job, add one `chronic -e` line per router, without `exec`.

### Testing

Run it directly:

```bash
openwrt-upgrade-check --host 192.168.1.1
```

## gear-lever-appimage-upgrade

Runs [Gear Lever](https://github.com/mijorus/gearlever) to update AppImages. Gear Lever is a per-user app, so the script runs as that user, never as root.

**Requires:** bash, flatpak and Gear Lever (`it.mijorus.gearlever`) installed as a flatpak for the user.

### Usage

```
gear-lever-appimage-upgrade [app-image-name]
```

- **No argument:** updates every AppImage Gear Lever manages.
- **`app-image-name`:** updates only that AppImage.
- **Who runs it:** either a logged-in user directly, or root through `runuser -u <user> -- gear-lever-appimage-upgrade`. The script reads only the `USER`, `LOGNAME`, `HOME` and `SHELL` variables that `runuser` sets (nothing else from the environment, which under cron may belong to root). It derives the rest itself, including the user's session bus (`/run/user/<uid>/bus`), and starts Gear Lever with a clean environment. Running as root without `runuser` is refused.
- **Not logged in:** if the user has no session bus yet, the script waits up to 1 hour for them to log in, then gives Gear Lever a minute to settle. If nobody logs in, it exits 0 without doing anything.
- **Output:** "No updates available" lines are dropped, so there is no output when nothing was updated.

Example daily cron job, saved as `/etc/cron.daily/x-gear-lever-appimage-upgrade`:

```bash
#!/usr/bin/env bash
runuser -u rahul -- gear-lever-appimage-upgrade
```

### Testing

Run it directly as the user, or as root through `runuser`:

```bash
gear-lever-appimage-upgrade
sudo runuser -u rahul -- gear-lever-appimage-upgrade
```
