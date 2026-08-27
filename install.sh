#!/usr/bin/env bash
# foxclick installer.
#
#   ./install.sh                 install + register Meta+X (KDE)
#   FOXCLICK_KEY="Meta+Shift+C" ./install.sh
#   FOXCLICK_KEY=none ./install.sh   skip the global shortcut
#
# Everything lands under $HOME; no root needed.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/foxclick"
app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
key="${FOXCLICK_KEY:-Meta+X}"

echo "installing foxclick"
mkdir -p "$bin_dir" "$cfg_dir" "$app_dir"

install -m 755 "$src/foxclick" "$bin_dir/foxclick"
echo "  $bin_dir/foxclick"

if [ -e "$cfg_dir/config" ]; then
    echo "  $cfg_dir/config  (kept - already exists)"
else
    install -m 644 "$src/config.example" "$cfg_dir/config"
    echo "  $cfg_dir/config"
fi

cat > "$app_dir/foxclick.desktop" <<EOF
[Desktop Entry]
Exec=$bin_dir/foxclick toggle
Name=Foxclick Toggle
NoDisplay=true
StartupNotify=false
Type=Application
X-KDE-GlobalAccel-CommandShortcut=true
EOF
echo "  $app_dir/foxclick.desktop"

case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) echo "  note: $bin_dir is not on your PATH" ;;
esac

# ---- KDE global shortcut (best effort) ----
if [ "$key" = none ] || [ "$key" = None ]; then
    echo "skipping global shortcut (FOXCLICK_KEY=none)"
    exit 0
fi
if ! command -v kwriteconfig6 >/dev/null 2>&1; then
    echo "not KDE Plasma - skipping automatic global shortcut."
    echo "Bind '$bin_dir/foxclick toggle' to a key in your compositor/DE config."
    echo "See the 'Global shortcut' section of the README for per-environment examples."
    exit 0
fi

# Translate a "Meta+Shift+X" style string into a Qt key-combination integer.
qt_keycode() {
    local spec="$1" total=0 part key
    IFS='+' read -ra parts <<< "$spec"
    for part in "${parts[@]}"; do
        case "${part,,}" in
            meta|super|win) total=$(( total + 0x10000000 )) ;;
            ctrl|control)   total=$(( total + 0x04000000 )) ;;
            alt)            total=$(( total + 0x08000000 )) ;;
            shift)          total=$(( total + 0x02000000 )) ;;
            f[1-9]|f1[0-9]) total=$(( total + 0x01000030 + ${part#[Ff]} - 1 )) ;;
            [a-z])          printf -v key '%d' "'${part^^}"; total=$(( total + key )) ;;
            [0-9])          printf -v key '%d' "'$part";      total=$(( total + key )) ;;
            *) echo "cannot parse key part: $part" >&2; return 1 ;;
        esac
    done
    echo "$total"
}

kwriteconfig6 --file kglobalshortcutsrc --group services --group foxclick.desktop \
    --key _launch "$key"

code="$(qt_keycode "$key" 2>/dev/null || true)"
if [ -n "$code" ] && command -v gdbus >/dev/null 2>&1; then
    aid="['foxclick.desktop', '_launch', 'Foxclick Toggle', 'Launch']"
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.doRegister "$aid" >/dev/null 2>&1 || true
    if gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.setShortcut "$aid" "[$code]" 2 >/dev/null 2>&1; then
        echo "global shortcut: $key  (active now)"
        exit 0
    fi
fi
echo "global shortcut: $key  (written; active after next login)"
