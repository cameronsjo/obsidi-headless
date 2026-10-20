#!/bin/sh
# Fake `ob` for tests. FAKE_OB_MODE: chatty (line/sec), hang (one line, then
# silence), hang-term (one line, then silence that ignores SIGTERM).
case "$1" in
    --version) echo fake; exit 0 ;;
    sync-status) echo "Vault: fake"; exit 0 ;;
esac
echo "Connecting..."
case "$FAKE_OB_MODE" in
    chatty) while :; do sleep 1; echo "tick"; done ;;
    hang) exec sleep 300 ;;
    hang-term) trap '' TERM; while :; do sleep 1; done ;;
esac
