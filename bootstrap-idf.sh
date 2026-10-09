#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IDF_PATH="$ROOT/dependencies/esp-idf"
export IDF_TOOLS_PATH="$ROOT/dependencies/.espressif"
export PATH="$ROOT/dependencies/.host-tools/usr/bin:$PATH"

required=(git python3 cmake ninja flex bison gperf)
missing=()
for tool in "${required[@]}"; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if ((${#missing[@]})); then
  printf 'Missing host prerequisites: %s\n' "${missing[*]}" >&2
  echo "Ubuntu/Debian: sudo apt install git python3 python3-venv cmake ninja-build flex bison gperf ccache libffi-dev libssl-dev dfu-util libusb-1.0-0" >&2
  exit 1
fi

git -C "$ROOT" submodule update --init --recursive
if ! compgen -G "$IDF_TOOLS_PATH/tools/xtensa-esp-elf/*/xtensa-esp-elf/bin/xtensa-esp32s3-elf-gcc" >/dev/null; then
  (cd "$IDF_PATH" && ./install.sh esp32s3)
fi

printf 'ESP-IDF source: %s\n' "$IDF_PATH"
printf 'ESP-IDF tools:  %s\n' "$IDF_TOOLS_PATH"
echo "Next: . ./idf-env.sh"