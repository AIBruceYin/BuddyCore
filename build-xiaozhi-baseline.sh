#!/usr/bin/env bash
set -euo pipefail

# BuddyCore firmware baseline build (branch xiaozhiAI).
#
# xiaozhi-esp32 is pinned to v2.3.0, the newest upstream release whose mainline
# targets ESP-IDF 5.x: it declares "idf: version: '>=5.5.2'" in
# main/idf_component.yml and its Kconfig default board is
# BOARD_TYPE_BREAD_COMPACT_WIFI. v2.4.0 and later moved the mainline to
# ESP-IDF 6.x, which this project does not install yet.
#
# At this pin the canonical build is plain idf.py. Board selection is a Kconfig
# choice (main/Kconfig.projbuild) that main/CMakeLists.txt maps to
# main/boards/<board>, and BOARD_NAME is a required compile-time identity (the
# device name reported over OTA/protocol). There is no scripts/build.py yet.
# Only build one board per invocation: the build directory holds that board's
# generated sdkconfig.
#
# The upstream checkout stays untouched: BuddyCore firmware changes live in
# dependencies/patches/xiaozhi-esp32/*.patch and are applied to a copy of the
# tree under build/, while generated sdkconfig and build output also stay there.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XIAOZHI_SUB="$ROOT/dependencies/xiaozhi-esp32"
PATCH_DIR="$ROOT/dependencies/patches/xiaozhi-esp32"
XIAOZHI_DIR="${BUDDYCORE_XIAOZHI_BUILD_SRC:-$ROOT/build/xiaozhi-esp32/src}"
BOARD_NAME="${BUDDYCORE_XIAOZHI_BOARD_NAME:-bread-compact-wifi}"
BOARD_CONFIG="${BUDDYCORE_XIAOZHI_BOARD_CONFIG:-CONFIG_BOARD_TYPE_BREAD_COMPACT_WIFI=y}"
EXTRA_CONFIG="${BUDDYCORE_XIAOZHI_EXTRA_CONFIG:-}"
BUILD_DIR="${BUDDYCORE_XIAOZHI_BUILD_DIR:-$ROOT/build/xiaozhi-esp32/$BOARD_NAME}"
BOARD_DEFAULTS="$ROOT/build/xiaozhi-esp32/$BOARD_NAME.board.defaults"

if [[ ! -f "$XIAOZHI_SUB/main/Kconfig.projbuild" ]]; then
  echo "xiaozhi-esp32 submodule is missing or incomplete. Run: git submodule update --init --recursive" >&2
  exit 1
fi

# Work on a copy so the submodule stays pristine while patches are applied to the
# tree that gets built (managed_components/ is gitignored there as well).
if [[ ! -f "$XIAOZHI_DIR/main/Kconfig.projbuild" ]]; then
  echo "Copying xiaozhi-esp32 to $XIAOZHI_DIR (first build)"
  mkdir -p "$XIAOZHI_DIR"
  tar -C "$XIAOZHI_SUB" --exclude=.git -cf - . | tar -C "$XIAOZHI_DIR" -xf -
fi
rm -f "$XIAOZHI_DIR/.git"

if [[ -d "$PATCH_DIR" ]]; then
  for patch in "$PATCH_DIR"/*.patch; do
    [[ -e "$patch" ]] || continue
    name="$(basename "$patch")"
    if git -C "$XIAOZHI_DIR" apply --check "$patch" 2>/dev/null; then
      git -C "$XIAOZHI_DIR" apply "$patch" || { echo "Applying firmware patch failed: $name" >&2; exit 1; }
      echo "applied firmware patch: $name"
    elif git -C "$XIAOZHI_DIR" apply --check --reverse "$patch" 2>/dev/null; then
      echo "firmware patch already applied: $name"
    else
      echo "Firmware patch neither applies nor reverses in $XIAOZHI_DIR ($name)." >&2
      echo "Delete $XIAOZHI_DIR and retry." >&2
      exit 1
    fi
  done
fi

source "$ROOT/idf-env.sh"

mkdir -p "$BUILD_DIR"
{
  printf '%s\n' "$BOARD_CONFIG"
  if [[ -n "$EXTRA_CONFIG" ]]; then
    printf '%s\n' "$EXTRA_CONFIG"
  fi
} > "$BOARD_DEFAULTS"

echo "ESP-IDF:       $(idf.py --version 2>/dev/null || echo unknown)"
echo "xiaozhi-esp32: $(git -C "$XIAOZHI_SUB" describe --tags --always) ($(git -C "$XIAOZHI_SUB" rev-parse --short HEAD))"
echo "build source:   $XIAOZHI_DIR"
echo "board=$BOARD_NAME ($BOARD_CONFIG)"

# ESP-IDF also applies "<file>.<target>" next to each defaults file, so the
# upstream sdkconfig.defaults.esp32s3 is picked up automatically.
export SDKCONFIG_DEFAULTS="$XIAOZHI_DIR/sdkconfig.defaults;$BOARD_DEFAULTS"

idf.py -C "$XIAOZHI_DIR" -B "$BUILD_DIR" \
  -DSDKCONFIG="$BUILD_DIR/sdkconfig" \
  -DIDF_TARGET=esp32s3 \
  -DBOARD_NAME="$BOARD_NAME" \
  build

echo "Baseline build finished: $BUILD_DIR"
echo "Upstream default board baseline, not a release image: confirm board model, flash size,"
echo "display/audio parts, pinout and partition layout before flashing."
