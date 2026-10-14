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
| `./build-xiaozhi-baseline.sh` | Sources `idf-env.sh` itself, then runs xiaozhi-esp32's canonical board/variant build (`scripts/build.py`) for the ESP32-S3 baseline. | Each time the firmware baseline needs building. No prior manual environment step is required. |

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

The baseline builds xiaozhi-esp32's `bread-compact-wifi` variant with its 16 MB flash partition table by default; override `BUDDYCORE_XIAOZHI_BOARD`, `BUDDYCORE_XIAOZHI_VARIANT` and `BUDDYCORE_XIAOZHI_LANGUAGE` when a different upstream board or locale is needed. S3R8 identifies the chip/PSRAM configuration, not a complete board. Do not flash this output until board model, flash size, display/audio components, pinout and partition layout have been confirmed. Project-owned non-secret build defaults are in `config/firmware/`; Lisa Beck's persona source is `config/Lisa.Beck/SOUL.md`, and her reference data is grouped in `datasets/Lisa.Beck/`.

xiaozhi-esp32 currently requires ESP-IDF 6.0.1 or newer, while the `esp-idf` submodule still pins v5.5.5, so the firmware build fails until that pin is raised or xiaozhi-esp32 is pinned to an older IDF-5.x-compatible release. See the version note in `dependencies/README.md` before building.

Build artifacts and generated sdkconfig live under ignored `build/`. Never put Wi-Fi credentials, API keys or private URLs in tracked defaults. Use environment variables or a local ignored config for secrets.
