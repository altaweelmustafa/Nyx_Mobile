#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Brager — desktop app refresher
# Rebuilds the Linux release binary and reinstalls it into the desktop
# app location set up alongside the "Nyx" launcher entry
# (~/.local/share/applications/nyx.desktop). The installed copy is a
# snapshot, not a live link to this repo -- run this after any change
# you want reflected in the app launched from your app menu.
# Run from the root of your Flutter project:  bash refresh_desktop_app.sh
# ─────────────────────────────────────────────────────────────────
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC}  $1"; }
success() { echo -e "${GREEN}[done]${NC}  $1"; }

INSTALL_DIR="$HOME/.local/share/nyx-app"

info "Building release bundle..."
flutter build linux --release

info "Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r build/linux/x64/release/bundle/* "$INSTALL_DIR/"

success "Nyx refreshed -- relaunch it from your app menu to pick up the update."
