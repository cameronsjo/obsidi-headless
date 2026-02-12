# obsidian-headless

Minimal headless Obsidian container. Xvfb + the Obsidian desktop app — no VNC, no desktop environment, no GUI overhead.

Designed for server-side use where you need Obsidian running (for Sync, plugins, or CLI access) without anyone sitting at a screen.

## Quick Start

```bash
docker run -d \
  --name obsidian \
  -v obsidian-config:/config \
  ghcr.io/cameronsjo/obsidian-headless:latest
```

## What's Inside

- **Obsidian** AppImage extracted and ready to run
- **Xvfb** virtual framebuffer (Electron needs a display, even headless)
- **Graceful shutdown** via SIGTERM handling
- **Healthcheck** via Obsidian CLI

## What's NOT Inside

- No VNC server
- No desktop environment
- No web UI
- No window manager

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Container timezone |
| `DISPLAY` | `:99` | X display (managed by entrypoint) |

### Volumes

| Path | Purpose |
|------|---------|
| `/config` | Obsidian config, plugins, and vault data. `HOME` is set to this path |

### User

Runs as UID `99` / GID `100` (matches Unraid's `nobody:users`). Override with `--user` if needed.

## Building

```bash
docker build -t obsidian-headless .

# Specific Obsidian version
docker build --build-arg OBSIDIAN_VERSION=1.12.1 -t obsidian-headless .
```

## Part of OBaaS

This image is a component of [OBaaS (Obsidian-as-a-Service)](https://github.com/cameronsjo/obaas) — a pattern for running Obsidian on a server to unlock AI agent access, encrypted backup, and multi-device sync.

## License

MIT
