#!/bin/sh
# Copies this computer's Nyx library (liked songs, playlists, profile and
# avatar) to the server, where the web app picks it up: a fresh install
# starts from it, and Sync Library -> "Restore Desktop Library" reloads it.
# Re-run whenever you want the web app to get a newer copy.
# Asks for the server password.
set -e
HOST=${NYX_HOST:-debian@100.105.90.110}
SRC=${NYX_LIBRARY:-$HOME/.local/share/com.example.brager}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# .backup gives a consistent copy even if the desktop app is running.
sqlite3 "$SRC/brager.db" ".backup '$TMP/brager.db'"
[ -f "$SRC/avatar.jpg" ] && cp "$SRC/avatar.jpg" "$TMP/"
tar -czf - -C "$TMP" . | ssh "$HOST" "mkdir -p apps/nyx-library && tar -xzf - -C apps/nyx-library"
echo "Library published."
