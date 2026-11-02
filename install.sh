#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo " NoteExport Installer"
echo "=========================================="

# Build if needed
if [ ! -d "$SCRIPT_DIR/build/NoteExport.app" ]; then
    echo "Building NoteExport..."
    bash "$SCRIPT_DIR/build.sh"
fi

INSTALL_DIR="/Applications"
if [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
fi

echo "Installing NoteExport.app to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/NoteExport.app"
cp -R "$SCRIPT_DIR/build/NoteExport.app" "$INSTALL_DIR/"

# Remove quarantine attribute just in case
xattr -rd com.apple.quarantine "$INSTALL_DIR/NoteExport.app" 2>/dev/null || true

# CLI optional link
if [ -d "$HOME/.local/bin" ] && [ -w "$HOME/.local/bin" ]; then
    ln -sf "$INSTALL_DIR/NoteExport.app/Contents/MacOS/NoteExport" "$HOME/.local/bin/note-export"
    echo "Linked CLI to $HOME/.local/bin/note-export"
elif [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    ln -sf "$INSTALL_DIR/NoteExport.app/Contents/MacOS/NoteExport" "/usr/local/bin/note-export"
    echo "Linked CLI to /usr/local/bin/note-export"
fi

echo "=========================================="
echo " NoteExport has been successfully installed!"
echo " Location: $INSTALL_DIR/NoteExport.app"
echo ""
echo " To launch now, open Finder and click NoteExport,"
echo " or run:"
echo "   open $INSTALL_DIR/NoteExport.app"
echo "=========================================="
