#!/bin/sh
# Fake `ob` for tests. FAKE_OB_MODE: chatty (line/sec), hang (one line, then
# silence), hang-term (one line, then silence that ignores SIGTERM), synced
# (`Fully synced` every second), synced-crlf (the same with a trailing CR),
# connecting (a reconnect loop that never syncs), lookalike (lines that contain
# `Fully synced` but are not that line). FAKE_OB_UNCONFIGURED=1 makes
# sync-status exit 3, as ob does for a vault with no sync configuration.
case "$1" in
    --version) echo fake; exit 0 ;;
    sync-status)
        [ "${FAKE_OB_UNCONFIGURED:-0}" = 1 ] && exit 3
        echo "Vault: fake"; exit 0 ;;
esac
echo "Connecting..."
case "$FAKE_OB_MODE" in
    chatty) while :; do sleep 1; echo "tick"; done ;;
    hang) exec sleep 300 ;;
    hang-term) trap '' TERM; while :; do sleep 1; done ;;
    synced) while :; do sleep 1; echo "Fully synced"; done ;;
    synced-crlf) while :; do sleep 1; printf 'Fully synced\r\n'; done ;;
    connecting) while :; do sleep 1; echo "Disconnected"; echo "Connecting..."; done ;;
    lookalike)
        while :; do
            sleep 1
            echo "Upload failed Fully synced.md"
            echo "Fully synced."
            echo " Fully synced"
        done ;;
esac
