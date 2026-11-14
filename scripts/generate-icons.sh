#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
logo_source="$project_dir/shared/assets/branding/logo-original.jpg"
for item in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density="${item%:*}"
  pixels="${item#*:}"
  magick "$logo_source" -resize "${pixels}x${pixels}" "$project_dir/mobile/android/app/src/main/res/mipmap-$density/ic_launcher.png"
done
magick "$logo_source" -resize 512x512 "$project_dir/desktop/linux/icons/app.nexodrop.nexodrop_desktop.png"
magick "$logo_source" -resize 256x256 "$project_dir/shared/assets/branding/logo.png"

magick "$logo_source" -define icon:auto-resize=256,128,64,48,32,16 "$project_dir/desktop/windows/runner/resources/app_icon.ico"
