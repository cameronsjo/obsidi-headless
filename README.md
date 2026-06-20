# obsidi-headless

Headless Obsidian Sync container powered by the official [`obsidian-headless`](https://github.com/obsidianmd/obsidian-headless) npm package. Keeps a vault continuously synced on a server without the desktop app.

## Quick Start

```bash
docker run -d \
  --name obsidian-sync \
  -v obsidian-config:/config \
  -v /path/to/vault:/vault \
  ghcr.io/cameronsjo/obsidi-headless:latest
```

## First-Run Setup

The container needs Obsidian Sync credentials configured once before continuous sync works.

### 1. Log in

```bash
docker run -it --rm \
  -v obsidian-config:/config \
  ghcr.io/cameronsjo/obsidi-headless:latest \
  su-exec 99:100 ob login
```

### 2. Set up sync

```bash
# List available remote vaults
docker run -it --rm \
  -v obsidian-config:/config \
  ghcr.io/cameronsjo/obsidi-headless:latest \
  su-exec 99:100 ob sync-list-remote

# Connect to a vault
docker run -it --rm \
  -v obsidian-config:/config \
  -v /path/to/vault:/vault \
  ghcr.io/cameronsjo/obsidi-headless:latest \
  su-exec 99:100 ob sync-setup --vault "Your Vault Name" --path /vault
```

### 3. Run

```bash
docker run -d \
  --name obsidian-sync \
  -v obsidian-config:/config \
  -v /path/to/vault:/vault \
  ghcr.io/cameronsjo/obsidi-headless:latest
```

## What's Inside

- **[obsidian-headless](https://www.npmjs.com/package/obsidian-headless)** — official Obsidian CLI for Sync and Publish
- **tini** — proper PID 1 for signal handling
- **su-exec** — privilege drop after volume permission fix

## What Changed (v2.0)

| | v1 (Electron) | v2 (obsidian-headless) |
|---|---|---|
| Base | Debian + Xvfb + AppImage | Node.js 22 Alpine |
| Image size | ~400MB | ~180MB |
| Dependencies | 20+ Electron libs | tini + su-exec |
| Startup | Boot X server, launch Electron, poll CLI | `ob sync --continuous` |
| License | Catalyst required | Sync subscription only |

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Container timezone |

### Volumes

| Path | Purpose |
|------|---------|
| `/config` | obsidian-headless state (credentials, sync metadata) |
| `/vault` | Your Obsidian vault |

Mount `/run/obsidi` as a `tmpfs` for best practice (it holds only ephemeral state):

```yaml
tmpfs:
  - /run/obsidi:uid=99,gid=100,mode=755
```

### Runtime State (`/run/obsidi`)

The container writes liveness state to `/run/obsidi/` (tmpfs — gone on container stop by design).

| File | Purpose |
|------|---------|
| `/run/obsidi/heartbeat` | Touched on every stdout line from `ob sync` and every 60s by the poller. The HEALTHCHECK requires mtime ≤ 5 min old. |
| `/run/obsidi/heartbeat.json` | JSON snapshot: `{"ts":"...", "state":"syncing", "remote_vault":"..."}`. Updated every 60s by a background `ob sync-status` call. |
| `/run/obsidi/unconfigured` | Sentinel created when `/vault` has no sync configuration. Presence makes the HEALTHCHECK report `unhealthy` immediately. |

External monitors (Gatus, etc.) can check `docker inspect --format '{{.State.Health.Status}}'` or read `heartbeat.json` via a sidecar.

### User

Runs as UID `99` / GID `100` (matches Unraid's `nobody:users`). Override with `--user` if needed.

### Fail-Loud Behavior

If `/vault` is not configured for Obsidian Sync (i.e., `ob sync-setup` was never run), the container:

1. Emits a structured JSON fatal log identifying the problem and the fix.
2. Creates `/run/obsidi/unconfigured` so the HEALTHCHECK reports `unhealthy`.
3. Sleeps 30 seconds to rate-limit the crashloop before exiting with code **78** (EX_CONFIG).

This replaces the previous silent millisecond crashloop (108,683 restarts in production before discovery).

## Building

```bash
docker build -t obsidi-headless .

# Pin obsidian-headless version
docker build --build-arg OBSIDIAN_HEADLESS_VERSION=0.0.8 -t obsidi-headless .
```

## Part of OBaaS

This image is a component of [OBaaSS (Obsidian As-a Safe-ish Service)](https://github.com/cameronsjo/obaass) — a pattern for running Obsidian on a server to unlock AI agent access, encrypted backup, and multi-device sync.

## License

[PolyForm Noncommercial 1.0.0](LICENSE). Commercial use requires a separate license — [get in touch](https://github.com/cameronsjo).

Obsidian Sync requires an active [Obsidian Sync subscription](https://obsidian.md/sync). The `obsidian-headless` npm package is maintained by [Obsidian](https://obsidian.md) — see [NOTICE.md](NOTICE.md).
