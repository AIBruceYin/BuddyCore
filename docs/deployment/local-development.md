# Local Development

## Repository Setup

Clone BuddyCore with its dependencies, or initialize existing submodules:

```sh
git clone --recurse-submodules <BuddyCore-repository-url>
cd BuddyCore
git submodule update --init --recursive
```

The submodule commits are recorded by the parent repository. Check `dependencies/README.md` before intentionally updating either pin.

## ESP-IDF Environment

The three root-level ESP-IDF scripts have separate roles:

| Script | Role | How often |
| --- | --- | --- |
| `./bootstrap-idf.sh` | Checks host prerequisites, initializes pinned source submodules, and installs ESP32-S3 compiler/tools plus the IDF Python environment into ignored `dependencies/.espressif/`. | First setup, or when repairing/reinstalling the local toolchain. Safe to rerun. |
| `. ./idf-env.sh` | Sources ESP-IDF's `export.sh` into the current shell and sets `IDF_PATH`, `IDF_TOOLS_PATH` and `PATH`. It must be sourced, not run as a child process, for the environment to remain active. | Once per new shell when running `idf.py` manually. |
| `./build-xiaoclaw-baseline.sh` | Sources `idf-env.sh` itself, applies the tracked XiaoClaw patch to an isolated worktree, then runs the ESP32-S3 cross-build. | Each time the firmware baseline needs building. No prior manual environment step is required. |

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

Build the pinned XiaoClaw ESP32-S3 software baseline without flashing:

```sh
./build-xiaoclaw-baseline.sh
```

The baseline intentionally inherits XiaoClaw's `BREAD_COMPACT_WIFI` board choice and 32 MB flash partition. S3R8 identifies the chip/PSRAM configuration, not a complete board. Do not flash this output until board model, flash size, display/audio components, pinout and partition layout have been confirmed. Project-owned non-secret build defaults are in `config/firmware/`; Lisa Beck's persona source is `config/Lisa.Beck/SOUL.md`, and her reference data is grouped in `datasets/Lisa.Beck/`.

Build artifacts and generated sdkconfig live under ignored `build/`. Never put Wi-Fi credentials, API keys or private URLs in tracked defaults. Use environment variables or a local ignored config for secrets.