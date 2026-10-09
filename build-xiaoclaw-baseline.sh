#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XIAOCLAW="$ROOT/dependencies/xiaoclaw"
PATCH="$ROOT/dependencies/patches/xiaoclaw/0001-fix-lamp-controller-conflict.patch"
BUILD_DIR="$ROOT/build/xiaoclaw-s3-worktree-baseline"
SDKCONFIG="$ROOT/build/sdkconfig.xiaoclaw-s3-worktree-baseline"
SOURCE_DIR="$ROOT/build/source-xiaoclaw-s3-baseline"

source "$ROOT/idf-env.sh"

PINNED_COMMIT="$(git -C "$XIAOCLAW" rev-parse HEAD)"
mkdir -p "$ROOT/build"
if [[ ! -e "$SOURCE_DIR" ]]; then
  git -C "$XIAOCLAW" worktree add --detach "$SOURCE_DIR" "$PINNED_COMMIT"
elif [[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" != "$PINNED_COMMIT" ]]; then
  echo "Existing source worktree does not match the pinned XiaoClaw submodule commit." >&2
  exit 1
fi

if git -C "$SOURCE_DIR" apply --unidiff-zero --reverse --check "$PATCH" >/dev/null 2>&1; then
  : # Patch is already applied.
elif git -C "$SOURCE_DIR" apply --unidiff-zero --check "$PATCH" >/dev/null 2>&1; then
  git -C "$SOURCE_DIR" apply --unidiff-zero "$PATCH"
else
  echo "XiaoClaw source worktree differs from the pinned baseline; inspect it before applying the patch." >&2
  exit 1
fi

export SDKCONFIG_DEFAULTS="$SOURCE_DIR/sdkconfig.defaults.esp32s3;$ROOT/config/firmware/sdkconfig.host.defaults"
idf.py -C "$SOURCE_DIR" -B "$BUILD_DIR" \
  -DSDKCONFIG="$SDKCONFIG" \
  -DIDF_TARGET=esp32s3 \
  build

echo "Baseline build complete: $BUILD_DIR/xiaozhi.bin"
echo "This uses XiaoClaw's default board and 32 MB flash assumptions. Do not flash it to an unverified board."