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
| `./start-server.sh` | Renders `deploy/server/data/.config.yaml` from `config/server/*.template` and runs the Docker deployment of xiaozhi-esp32-server (`deploy/server/docker-compose.yml`). Subcommands: `up`, `config`, `status`, `logs`, `pull`, `restart`, `down`. | Whenever the voice/LLM service is needed; copy `deploy/server/.env.example` to `.env` first. |

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

## Server (Docker)

The self-hosted xiaozhi-esp32-server runs through Docker and needs no ESP-IDF environment:

```sh
cp deploy/server/.env.example deploy/server/.env   # then fill in secrets
./start-server.sh up
```

`start-server.sh` renders the server config into the ignored `deploy/server/data/.config.yaml` and keeps upstream default ports (8000 WebSocket, 8003 server HTTP, 8002 console). Without `MANAGER_SECRET` it runs the single-service local mode; with it, the console containers start too. Details, modes and the current model-access status are in [deploy/README.md](../../deploy/README.md#server-deployment-docker).

## Firmware on a Windows host

`build-xiaozhi-baseline.sh` targets Linux/bash. On Windows use the companion script:

```powershell
$env:IDF_TOOLS_PATH = "$PWD\dependencies\.espressif"
$env:IDF_GITHUB_ASSETS = "dl.espressif.com/github_assets"   # China: avoid github.com timeouts
& .\dependencies\esp-idf\install.ps1 esp32s3

$env:BUDDYCORE_XIAOZHI_BOARD_NAME   = "esp32-s3-touch-lcd-1.85c"
$env:BUDDYCORE_XIAOZHI_BOARD_CONFIG = "CONFIG_BOARD_TYPE_WAVESHARE_ESP32_S3_TOUCH_LCD_1_85C=y"
$env:BUDDYCORE_XIAOZHI_EXTRA_CONFIG_FILE = "config\firmware\sdkconfig.buddycore-s3-touch-lcd-1.85c.defaults"
$env:BUDDYCORE_XIAOZHI_EXTRA_CONFIG = "CONFIG_OTA_URL=`"http://<host>:8003/xiaozhi/ota/`""
$env:BUDDYCORE_XIAOZHI_SHORT_ROOT   = "D:\zs"    # Windows command-line limit workaround
$env:BUDDYCORE_XIAOZHI_BUILD_DIR    = "D:\zsz"
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-xiaozhi-baseline.ps1
```

Board specifics for the Waveshare ESP32-S3-Touch-LCD-1.85C kit (see `config/firmware/`):

* `CONFIG_VERSION_1_0=y` — the kit has no ES8311/ES7210 codec chips; the board's Kconfig default `VERSION_2_0` boots into `assert failed: BoxAudioCodec::BoxAudioCodec ... (out_codec_if_ != NULL)` on this hardware.
* Wake word `你好Lisa` is a MultiNet custom keyword (`CONFIG_CUSTOM_WAKE_WORD="ni hao li sa"`, `CONFIG_SR_MN_CN_MULTINET7_QUANT=y`); WakeNet models are a fixed vocabulary and cannot express it. MultiNet is recognition-based, so the threshold (`CONFIG_CUSTOM_WAKE_WORD_THRESHOLD`, default 20, lower = more sensitive) may need tuning per room.
* The BOOT button (GPIO0) click starts/stops a conversation without the wake word.

Three Windows-specific traps, all hit during the first real build:

1. Run `install.ps1` with no Python virtualenv active on `PATH`, otherwise ESP-IDF refuses to create its own venv. Add `IDF_GITHUB_ASSETS=dl.espressif.com/github_assets` first, otherwise crosstool-NG downloads from github.com time out.
2. The final compile command with 74 managed components exceeds Windows' 32 KiB command-line limit. Build from short paths (`BUDDYCORE_XIAOZHI_SHORT_ROOT`, `BUDDYCORE_XIAOZHI_BUILD_DIR`); a directory junction is not enough because CMake resolves it back to the long path.
3. Pass `-D` arguments to `idf.py` from a script file with quoted values: PowerShell mangles bare `-DSDKCONFIG=<drive>:\...` tokens.

Flashing and monitoring (the device exposes the ESP32-S3 USB-Serial/JTAG, so no extra driver is needed):

```powershell
idf.py -C D:\zs -B D:\zsz -p COM3 -b 460800 flash
```

Build artifacts and generated sdkconfig live under ignored `build/`. Never put Wi-Fi credentials, API keys or private URLs in tracked defaults. Use environment variables or a local ignored config for secrets.
