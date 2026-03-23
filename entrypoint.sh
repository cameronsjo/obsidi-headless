#!/bin/sh
set -eu

echo "Starting obsidi-headless sync container..."
echo "obsidian-headless version: $(ob --version 2>/dev/null || echo 'unknown')"

# Fix volume permissions (entrypoint runs as root)
chown -R 99:100 /vault /config

# Drop privileges and run continuous sync
# tini handles PID 1 responsibilities (signal forwarding, zombie reaping)
# su-exec drops to non-root after permission fix
exec su-exec 99:100 tini -- ob sync --continuous --path /vault
