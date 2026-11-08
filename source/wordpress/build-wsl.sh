#!/bin/bash
#
# Build wordpress.bin (Linux) di WSL dengan cepat.
#
# Source tetap diedit di drive Windows (/mnt/d/...), tapi compile dilakukan
# di filesystem native WSL ($BUILD_DIR) karena akses /mnt/* via 9P lambat.
# Hasil: public_html/wordpress.bin (menimpa binary Windows bila ada).
#
# Pemakaian:
#   ./build-wsl.sh          build incremental
#   ./build-wsl.sh clean    hapus cache build (unit .ppu/.o), lalu build ulang
#
# Lokasi build bisa diganti lewat env BUILD_DIR (default: ~/wordpress-build).
# FastPlaz dicari di ../../../vendors/fastplaz (sama dengan extra.cfg).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # .../source/wordpress
APP_ROOT="$(readlink -f "$SCRIPT_DIR/../..")"                   # .../FastPlaz-wordpress
VENDORS="$(readlink -f "$APP_ROOT/../vendors")"                 # .../source/vendors
SRC_FASTPLAZ="$VENDORS/fastplaz/FastPlaz"

BUILD_DIR="${BUILD_DIR:-$HOME/wordpress-build}"
B_APP="$BUILD_DIR/app"
B_VENDORS="$BUILD_DIR/vendors"
OUTPUT="$APP_ROOT/public_html/wordpress.bin"

[ -f "$SRC_FASTPLAZ/src/systems/fastplaz_app.pas" ] || {
  echo "ERROR: FastPlaz (dengan fastplaz_app) tidak ditemukan di $SRC_FASTPLAZ" >&2
  exit 1
}

if [ "${1:-}" = "clean" ]; then
  echo ">> clean: hapus $B_APP/source/wordpress"
  rm -rf "$B_APP/source/wordpress"
fi

# sync SRC/ -> DST/ ; hasil compile & folder lib/ tidak ikut disalin
# dan (untuk rsync) tidak dihapus di tujuan.
sync_dir() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git/' --exclude 'lib/' --exclude 'backup/' \
      --exclude '*.ppu' --exclude '*.o' --exclude '*.a' \
      --exclude '*.compiled' --exclude '*.bin' --exclude '*.exe' \
      "$src/" "$dst/"
  else
    # fallback tanpa rsync: hanya salin file yang lebih baru
    cp -a -u "$src/." "$dst/"
  fi
}

START=$(date +%s)
echo ">> sync source ke $BUILD_DIR"
# struktur dipertahankan agar path relatif di extra.cfg tetap berlaku:
#   $BUILD_DIR/app/source/wordpress  ->  ../../../vendors = $BUILD_DIR/vendors
sync_dir "$SCRIPT_DIR"   "$B_APP/source/wordpress"
sync_dir "$SRC_FASTPLAZ" "$B_VENDORS/fastplaz/FastPlaz"
mkdir -p "$B_APP/public_html"

cd "$B_APP/source/wordpress"
mkdir -p "lib/$(fpc -iTP)-$(fpc -iTO)"

echo ">> compile wordpress"
fpc wordpress.lpr @extra.cfg -o../../public_html/wordpress.bin
cp -f "$B_APP/public_html/wordpress.bin" "$OUTPUT"
chmod 755 "$OUTPUT"
echo ">> wordpress.bin -> $OUTPUT"
echo ">> selesai dalam $(( $(date +%s) - START )) detik"
