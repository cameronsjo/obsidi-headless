FROM node:22.23.5-alpine

ARG OBSIDIAN_HEADLESS_VERSION=0.0.8

LABEL org.opencontainers.image.source="https://github.com/cameronsjo/obsidi-headless" \
      org.opencontainers.image.description="Headless Obsidian Sync via obsidian-headless npm package" \
      org.opencontainers.image.licenses="PolyForm-Noncommercial-1.0.0"

# Create user matching Unraid nobody:users (UID 99, GID 100)
# node:22-alpine ships with 'node' at UID 1000 — remove it first
RUN deluser --remove-home node 2>/dev/null || true && \
    addgroup -g 100 -S users 2>/dev/null || true && \
    adduser -u 99 -G users -S -D -h /config obsidian && \
    mkdir -p /vault /config && \
    chown -R 99:100 /vault /config

RUN apk add --no-cache tini su-exec && \
    npm install -g obsidian-headless@${OBSIDIAN_HEADLESS_VERSION} && \
    npm cache clean --force && \
    # Pre-create the runtime state directory, root-owned (the entrypoint
    # re-asserts that). A new named volume copies this ownership at first mount.
    mkdir -p /run/obsidi && chmod 0755 /run/obsidi

# Root-owned: root runs it at every start, so uid 99 (which runs `ob`) must not
# be able to rewrite it in the container layer.
COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

COPY --chown=99:100 LICENSE NOTICE.md /licenses/

ENV TZ=UTC \
    HOME=/config

VOLUME ["/vault", "/config"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD test ! -f /run/obsidi/unconfigured \
     && pgrep -f "ob sync" >/dev/null 2>&1 \
     && test "$(($(date +%s) - $(stat -c %Y /run/obsidi/heartbeat 2>/dev/null || echo 0)))" -lt 300 \
     || exit 1

ENTRYPOINT ["/entrypoint.sh"]
