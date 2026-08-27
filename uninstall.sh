#!/usr/bin/env bash
# Remove what install.sh added. Keeps ~/.config/foxclick/config unless --purge.
set -euo pipefail

bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/foxclick"
app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

"$bin_dir/foxclick" stop 2>/dev/null || true

rm -fv "$bin_dir/foxclick" "$app_dir/foxclick.desktop"

if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kglobalshortcutsrc --group services --group foxclick.desktop \
        --key _launch --delete 2>/dev/null || true
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
            --method org.kde.KGlobalAccel.unRegister \
            "['foxclick.desktop', '_launch', 'Foxclick Toggle', 'Launch']" >/dev/null 2>&1 || true
    fi
    echo "removed KDE global shortcut"
fi

if [ "${1:-}" = --purge ]; then
    rm -rfv "$cfg_dir"
else
    echo "kept $cfg_dir  (use --purge to remove)"
fi
