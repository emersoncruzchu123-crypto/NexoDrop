#!/usr/bin/env bash
# Install a local release build. Never touches received files or history.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'Este instalador está preparado para Linux x86_64.' >&2
  exit 1
fi
missing=0
for tool in clang cmake ninja pkg-config git xz unzip curl; do
  command -v "$tool" >/dev/null || missing=1
done
if ! pkg-config --exists gtk+-3.0 2>/dev/null; then missing=1; fi
if (( missing )); then
  if ! command -v dnf >/dev/null; then
    echo 'Faltan herramientas de compilación o GTK 3. Consulta docs/linux.md.' >&2
    exit 1
  fi
  echo 'Se instalarán las dependencias de compilación mediante dnf.'
  sudo dnf install -y clang cmake ninja-build pkgconf-pkg-config gtk3-devel gcc-c++ git xz unzip curl
fi
if command -v flutter >/dev/null; then
  flutter_command="$(command -v flutter)"
else
  flutter_checkout="${XDG_CACHE_HOME:-$HOME/.cache}/nexodrop/flutter-3.44.5"
  if [[ ! -e "$flutter_checkout" ]]; then
    mkdir -p "$(dirname -- "$flutter_checkout")"
    echo 'Descargando Flutter 3.44.5 para compilar NexoDrop (solo la primera vez).'
    git clone --depth 1 --branch 3.44.5 https://github.com/flutter/flutter.git "$flutter_checkout"
  fi
  flutter_command="$flutter_checkout/bin/flutter"
  test -x "$flutter_command"
fi
(cd "$project_dir/desktop" && "$flutter_command" build linux --release)
bundle="$project_dir/desktop/build/linux/x64/release/bundle"
test -x "$bundle/nexodrop_desktop"
# Each installation uses its own directory, so an open instance keeps its libraries.
install_root="${XDG_DATA_HOME:-$HOME/.local/share}/nexodrop"
mkdir -p "$install_root/releases"
release_dir="$(mktemp -d "$install_root/releases/release-XXXXXXXX")"
cp -a "$bundle/." "$release_dir/"
cp "$project_dir/LICENSE" "$project_dir/NOTICE" "$release_dir/"
bash "$project_dir/scripts/install-linux-launcher.sh" "$release_dir"
printf '\nNexoDrop instalada. Ábrela desde el menú de aplicaciones.\nEjecutable: %s/nexodrop_desktop\n' "$release_dir"
