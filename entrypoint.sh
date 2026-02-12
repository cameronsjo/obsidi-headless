#!/bin/bash
set -euo pipefail

echo "Starting Obsidian headless container..."

# Start virtual framebuffer
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
XVFB_PID=$!

# Wait for X server
sleep 2

# Launch Obsidian headless
/opt/obsidian/obsidian --no-sandbox &
OBS_PID=$!

# Wait for CLI readiness
echo "Waiting for Obsidian to initialize..."
for i in $(seq 1 30); do
    if /opt/obsidian/obsidian version 2>/dev/null; then
        echo "Obsidian CLI ready."
        break
    fi
    sleep 3
done

# Graceful shutdown
cleanup() {
    echo "Shutting down Obsidian..."
    kill "$OBS_PID" 2>/dev/null || true
    kill "$XVFB_PID" 2>/dev/null || true
    wait
}
trap cleanup SIGTERM SIGINT

# Hold container open
wait "$OBS_PID"
