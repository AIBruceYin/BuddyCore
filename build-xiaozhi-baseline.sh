#!/usr/bin/env bash
set -euo pipefail

# BuddyCore firmware baseline build (branch xiaozhiAI).
#
# Delegates to xiaozhi-esp32's own canonical board/variant build entry point
# (scripts/build.py), which configures one board variant and runs idf.py for
# it. Board selection is a coupled chain in the upstream repository:
# config.json -> scripts/build.py -> main/Kconfig.projbuild -> main/CMakeLists.txt
# -> board source and config.h. Do not edit generated sdkconfig or the
# upstream checkout; add a uniquely named board or variant instead.
#
# ESP-IDF version: the pinned xiaozhi-esp32 requires ESP-IDF >= 6.0.1 and does
# not support IDF 5.x. The esp-idf submodule currently pinned at v5.5.5 cannot
# build this firmware. Raise the esp-idf pin (and rerun ./bootstrap-idf.sh)
# before relying on this script.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XIAOZHI_DIR="$ROOT/dependencies/xiaozhi-esp32"
BOARD="${BUDDYCORE_XIAOZHI_BOARD:-bread-compact-wifi}"
VARIANT="${BUDDYCORE_XIAOZHI_VARIANT:-bread-compact-wifi}"
LANGUAGE="${BUDDYCORE_XIAOZHI_LANGUAGE:-zh-CN}"

if [[ ! -f "$XIAOZHI_DIR/scripts/build.py" ]]; then
  echo "xiaozhi-esp32 submodule is missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

source "$ROOT/idf-env.sh"

echo "ESP-IDF:       $(idf.py --version 2>/dev/null || echo unknown)"
echo "xiaozhi-esp32: $(git -C "$XIAOZHI_DIR" rev-parse HEAD)"
echo "board=$BOARD variant=$VARIANT language=$LANGUAGE"

# List valid board/variant pairs with:
#   python3 dependencies/xiaozhi-esp32/scripts/build.py --list-boards
cd "$XIAOZHI_DIR"
python3 scripts/build.py "$BOARD" --name "$VARIANT" --language "$LANGUAGE"

echo "Baseline build finished. Upstream build output stays under $XIAOZHI_DIR/build/."
echo "This is the upstream default board baseline, not a release image: confirm board model,"
echo "flash size, display/audio parts, pinout and partition layout before flashing."
