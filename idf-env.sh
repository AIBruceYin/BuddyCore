#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this file: . ./idf-env.sh" >&2
  exit 2
fi

BUDDYCORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export IDF_PATH="$BUDDYCORE_ROOT/dependencies/esp-idf"
export IDF_TOOLS_PATH="$BUDDYCORE_ROOT/dependencies/.espressif"
export PATH="$BUDDYCORE_ROOT/dependencies/.host-tools/usr/bin:$PATH"

if [[ ! -f "$IDF_PATH/export.sh" ]]; then
  echo "ESP-IDF submodule is missing. Run: git submodule update --init --recursive" >&2
  return 1
fi

source "$IDF_PATH/export.sh"