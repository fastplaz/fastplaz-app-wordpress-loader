#!/bin/bash
#
# Build project FastPlaz di dalam Docker.
#
# Tujuan: binary kompatibel dengan server hosting yang glibc-nya lama
# (cPanel/CloudLinux 8 = glibc 2.28). Build di distro baru (glibc >= 2.34)
# menghasilkan binary yang butuh GLIBC_2.34 dan gagal jalan di server (error 500).
# Image luri/free-pascal (Ubuntu 20.04, FPC 3.2.2) menghasilkan binary yang hanya
# butuh GLIBC_2.2.5.
#
# Compiler diambil dari image; source & vendors (termasuk FastPlaz terbaru)
# di-mount dari disk lalu disalin ke volume docker (cache unit .ppu/.o) agar
# build incremental cepat.
#
# Struktur yang diharapkan (script ditaruh di folder modul):
#   <root>/source/<modul>/build-docker.sh, extra.cfg, *.lpr
#   <root>/public_html/                    output (modul "api" -> public_html/api)
#   <root>/../vendors/<nama>               vendor yang dirujuk extra.cfg
#                                          (-Fu../../../vendors/<nama>/...), boleh symlink
#
# Pemakaian (dari WSL, Git Bash, atau Linux yang punya akses docker;
# di WSL tanpa integrasi Docker Desktop otomatis memakai docker.exe):
#   ./build-docker.sh project          build incremental
#   ./build-docker.sh project clean    hapus cache build modul ini, lalu build ulang
#   ./build-docker.sh all              build semua project (*.lpr)
#
# Env:
#   FPC_IMAGE   image compiler (default: luri/free-pascal:multiarch)
#   OUT_SUBDIR  folder output relatif ke <root> (default: public_html,
#               atau public_html/api untuk modul api)

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "USAGE:"
  echo "  ./build-docker.sh yourproject [clean]"
  echo "  ./build-docker.sh all [clean]"
  exit 0
fi

# Pilih docker: native (Linux/Git Bash/WSL dengan integrasi Docker Desktop),
# atau docker.exe milik Windows dari dalam WSL (tanpa integrasi WSL).
DOCKER=""
if command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1; then
  DOCKER="docker"
elif command -v docker.exe >/dev/null 2>&1 && docker.exe version >/dev/null 2>&1; then
  DOCKER="docker.exe"
fi
[ -n "$DOCKER" ] || { echo "ERROR: docker tidak ditemukan / Docker Desktop belum berjalan" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
MODULE="$(basename "$SCRIPT_DIR")"
PROJECT_ROOT="$(readlink -f "$SCRIPT_DIR/../..")"
VENDORS="$(readlink -f "$PROJECT_ROOT/../vendors" 2>/dev/null || true)"

FPC_IMAGE="${FPC_IMAGE:-luri/free-pascal:multiarch}"
if [ -z "${OUT_SUBDIR:-}" ]; then
  if [ "$MODULE" = "api" ]; then OUT_SUBDIR="public_html/api"; else OUT_SUBDIR="public_html"; fi
fi
# satu volume cache per project root, misal: fpc-build-dashboard
VOLUME="fpc-build-$(basename "$PROJECT_ROOT" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_.\n-' '-')"

[ -f "$SCRIPT_DIR/extra.cfg" ] || { echo "ERROR: $SCRIPT_DIR/extra.cfg tidak ditemukan" >&2; exit 1; }
mkdir -p "$PROJECT_ROOT/$OUT_SUBDIR"

# path host untuk -v:
#   Git Bash/MSYS        /d/...     -> D:/...
#   WSL + docker.exe     /mnt/d/... -> D:/...
host_path() {
  if [ "$DOCKER" = "docker.exe" ] && command -v wslpath >/dev/null 2>&1; then
    wslpath -m "$1"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    echo "$1"
  fi
}

# vendor yang dirujuk extra.cfg: -Fu../../../vendors/<nama>/...
# tiap vendor di-mount terpisah karena symlink tidak bisa diikuti di dalam container.
VENDOR_MOUNTS=()
VENDOR_NAMES=""
for name in $(sed -n 's#^[[:space:]]*-F[uiIl]\.\./\.\./\.\./vendors/\([^/[:space:]]*\).*#\1#p' "$SCRIPT_DIR/extra.cfg" | tr -d '\r' | sort -u); do
  src="$(readlink -f "$VENDORS/$name" 2>/dev/null || true)"
  [ -n "$src" ] && [ -d "$src" ] || { echo "ERROR: vendor tidak ditemukan: $VENDORS/$name" >&2; exit 1; }
  VENDOR_MOUNTS+=(-v "$(host_path "$src"):/src/vendors/$name:ro")
  VENDOR_NAMES="$VENDOR_NAMES $name"
done

PROJECT="${1%.lpr}"
PROJECT="${PROJECT%.lpi}"
CLEAN="${2:-}"

START=$(date +%s)
echo ">> docker build ($FPC_IMAGE) $(basename "$PROJECT_ROOT")/source/$MODULE: $PROJECT"
echo ">> pakai: $DOCKER, vendors:${VENDOR_NAMES:- -}, output: $OUT_SUBDIR"

# Di dalam container:
#   /src/source         (ro)  -> <root>/source
#   /src/vendors/<nama> (ro)  -> vendor yang dirujuk extra.cfg
#   /out                      -> folder output di host
#   /build              (vol) -> salinan source + cache unit, struktur relatif sama:
#                                /build/project/source/<modul>, /build/vendors/<nama>
MSYS_NO_PATHCONV=1 "$DOCKER" run --rm --platform linux/amd64 \
  -v "$(host_path "$PROJECT_ROOT/source"):/src/source:ro" \
  "${VENDOR_MOUNTS[@]}" \
  -v "$(host_path "$PROJECT_ROOT/$OUT_SUBDIR"):/out" \
  -v "$VOLUME:/build" \
  -e MODULE="$MODULE" -e PROJECT="$PROJECT" -e CLEAN="$CLEAN" \
  "$FPC_IMAGE" bash -euo pipefail -c '
    B=/build/project
    if [ "$CLEAN" = "clean" ]; then
      echo ">> clean: hapus cache $B/source/$MODULE"
      rm -rf "$B/source/$MODULE"
    fi

    # salin hanya file yang lebih baru; file hasil compile & lib/ tidak ikut
    sync_dir() {
      mkdir -p "$2"
      tar -C "$1" -cf - \
        --exclude=.git --exclude=lib --exclude=backup \
        --exclude="*.ppu" --exclude="*.o" --exclude="*.a" \
        --exclude="*.compiled" --exclude="*.bin" --exclude="*.exe" . \
        | tar -C "$2" -xf - --keep-newer-files 2>/dev/null || true
    }
    sync_dir /src/source $B/source
    if [ -d /src/vendors ]; then
      for v in /src/vendors/*; do sync_dir "$v" "/build/vendors/$(basename "$v")"; done
    fi

    cd $B/source/$MODULE
    mkdir -p "lib/$(fpc -iTP)-$(fpc -iTO)" /build/out

    if [ "$PROJECT" = "all" ]; then
      PROJECTS=$(ls *.lpr | sed "s/\.lpr$//")
    else
      [ -f "$PROJECT.lpr" ] || { echo "ERROR: project file $PROJECT.lpr tidak ditemukan" >&2; exit 1; }
      PROJECTS="$PROJECT"
    fi

    FAILED=""
    for P in $PROJECTS; do
      echo ">> compile $P"
      if fpc "$P.lpr" @extra.cfg -o/build/out/$P.bin; then
        cp -f /build/out/$P.bin /out/$P.bin
        chmod 755 /out/$P.bin
        echo ">> $P.bin  ($(objdump -T /build/out/$P.bin | grep -o "GLIBC_[0-9.]*" | sort -uV | tail -1))"
      else
        FAILED="$FAILED $P"
      fi
    done
    if [ -n "$FAILED" ]; then echo "GAGAL:$FAILED" >&2; exit 1; fi
  '

echo ">> output: $PROJECT_ROOT/$OUT_SUBDIR"
echo ">> selesai dalam $(( $(date +%s) - START )) detik"
