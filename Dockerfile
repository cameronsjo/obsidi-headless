FROM debian:bookworm-slim

ARG OBSIDIAN_VERSION=1.8.9

# Minimal Electron dependencies + Xvfb for headless display
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    libgtk-3-0 \
    libnss3 \
    libgbm1 \
    libxss1 \
    libasound2 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libpango-1.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libx11-xcb1 \
    libxcb1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrender1 \
    libxtst6 \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and extract Obsidian AppImage
RUN wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/Obsidian-${OBSIDIAN_VERSION}.AppImage" \
        -O /tmp/obsidian.AppImage \
    && chmod +x /tmp/obsidian.AppImage \
    && cd /tmp && /tmp/obsidian.AppImage --appimage-extract \
    && mv /tmp/squashfs-root /opt/obsidian \
    && rm /tmp/obsidian.AppImage \
    && chmod -R a+rx /opt/obsidian

# Create config directory and set up non-root user (UID 99 = Unraid nobody)
RUN mkdir -p /config && chown 99:100 /config

USER 99:100

ENV HOME=/config
ENV DISPLAY=:99

COPY --chown=99:100 entrypoint.sh /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD /opt/obsidian/obsidian version > /dev/null 2>&1 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
