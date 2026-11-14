#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_dir="${1:-$project_dir/desktop/build/linux/x64/debug/bundle}"
app_binary="$bundle_dir/nexodrop_desktop"
app_icon="$bundle_dir/data/app.nexodrop.nexodrop_desktop.png"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
test -x "$app_binary"
mkdir -p "$data_dir/applications"
# Escape the executable path according to the desktop-entry Exec syntax.
exec_path="${app_binary//\\/\\\\}"
exec_path="${exec_path//\"/\\\"}"
exec_path="${exec_path//\$/\\\$}"
exec_path="${exec_path//\`/\\\`}"
exec_path="${exec_path//%/%%}"
cat > "$data_dir/applications/app.nexodrop.nexodrop_desktop.desktop" <<ENTRY
[Desktop Entry]
Type=Application
Name=NexoDrop
Comment=Comparte archivos entre tus dispositivos sin internet
Exec="$exec_path"
Icon=$app_icon
Terminal=false
Categories=Network;FileTransfer;
StartupWMClass=app.nexodrop.nexodrop_desktop
ENTRY
if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$data_dir/applications"
fi
