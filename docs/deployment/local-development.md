# Local Development

## Repository Setup

Clone BuddyCore with its dependencies, or initialize existing submodules:

```sh
git clone --recurse-submodules <BuddyCore-repository-url>
cd BuddyCore
git submodule update --init --recursive
```

The submodule commits are recorded by the parent repository. Check `dependencies/README.md` before intentionally updating any pin.

## ESP-IDF Environment

The three root-level ESP-IDF scripts have separate roles:

| Script | Role | How often |
| --- | --- | --- |
| `./bootstrap-idf.sh` | Checks host prerequisites, initializes pinned source submodules, and installs ESP32-S3 compiler/tools plus the IDF Python environment into ignored `dependencies/.espressif/`. | First setup, or when repairing/reinstalling the local toolchain. Safe to rerun. |
| `. ./idf-env.sh` | Sources ESP-IDF's `export.sh` into the current shell and sets `IDF_PATH`, `IDF_TOOLS_PATH` and `PATH`. It must be sourced, not run as a child process, for the environment to remain active. | Once per new shell when running `idf.py` manually. |
| `./build-xiaozhi-baseline.sh` | Sources `idf-env.sh` itself, then cross-builds the pinned xiaozhi-esp32 with `idf.py` (board chosen by the upstream Kconfig option) into an ignored per-board build directory. | Each time the firmware baseline needs building. No prior manual environment step is required. |

First-time setup from the BuddyCore root:

```sh
git submodule update --init --recursive
./bootstrap-idf.sh
. ./idf-env.sh
idf.py --version
```

Bootstrap installs host tools; it does not activate IDF in the shell that invoked it. Source the environment after bootstrap. In later terminals, source it again; do not reinstall tools unless they are missing or broken. The build script performs this environment activation internally.

`IDF_PATH`, `IDF_TOOLS_PATH`, compiler binaries and the IDF Python virtual environment resolve under BuddyCore. Host OS build prerequisites remain normal system packages; generated tool downloads are ignored by Git.

## Checks and Firmware Baseline

Run host-only contract tests at any time; they do not require ESP-IDF:

```sh
./test-host.sh
```

Build the pinned xiaozhi-esp32 ESP32-S3 software baseline without flashing:

```sh
./build-xiaozhi-baseline.sh
```

The baseline builds xiaozhi-esp32 `v2.3.0`'s default `bread-compact-wifi` board with its 16 MB flash partition table into `build/xiaozhi-esp32/bread-compact-wifi/`. Override `BUDDYCORE_XIAOZHI_BOARD_NAME` (board directory name, also passed as the `BOARD_NAME` device identity macro that the firmware reports to the server), `BUDDYCORE_XIAOZHI_BOARD_CONFIG` (the `CONFIG_BOARD_TYPE_*` symbol, e.g. `CONFIG_BOARD_TYPE_BREAD_COMPACT_WIFI_LCD=y`), `BUDDYCORE_XIAOZHI_EXTRA_CONFIG` (extra Kconfig lines appended to the board defaults, e.g. locale or OTA URL) or `BUDDYCORE_XIAOZHI_BUILD_DIR` when a different upstream board is needed; one board per build directory, because the generated `sdkconfig` belongs to that board. S3R8 identifies the chip/PSRAM configuration, not a complete board. Do not flash this output until board model, flash size, display/audio components, pinout and partition layout have been confirmed. Project-owned non-secret build defaults are in `config/firmware/`; Lisa Beck's persona source is `config/Lisa.Beck/SOUL.md`, and her reference data is grouped in `datasets/Lisa.Beck/`.

The `esp-idf` submodule pins v5.5.5 and xiaozhi-esp32 is pinned to `v2.3.0`, the newest upstream release whose mainline targets ESP-IDF 5.x (it declares `idf: version: '>=5.5.2'`). Moving xiaozhi-esp32 to v2.4.0 or later requires an ESP-IDF 6.0.x pin first; that upgrade is deliberately deferred. See the version note in `dependencies/README.md`.

Build artifacts and generated sdkconfig live under ignored `build/`. Never put Wi-Fi credentials, API keys or private URLs in tracked defaults. Use environment variables or a local ignored config for secrets.
