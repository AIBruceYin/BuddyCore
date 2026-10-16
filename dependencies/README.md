# Dependencies

Source dependencies are checked out inside this directory as Git submodules:

| Path | Upstream | Pinned revision |
| --- | --- | --- |
| `xiaozhi-esp32/` | https://github.com/78/xiaozhi-esp32 | release `v2.3.0`, commit `1b48ebd7863695bf80d384c6c09af6299a6d7d0e` (pinned 2026-10-14) |
| `xiaozhi-esp32-server/` | https://github.com/xinnan-tech/xiaozhi-esp32-server | commit `27399a2fb64b5910196f438a256ce0a9f868481f` (branch `main`, pinned 2026-10-14) |
| `esp-idf/` | https://github.com/espressif/esp-idf | commit `b774170ff46c393eeb5e495ea37936038d3f4f4f` (ESP-IDF `v5.5.5`) |

Branch `xiaozhiAI` builds on XiaoZhi instead of XiaoClaw: `xiaozhi-esp32` is the device firmware base and `xiaozhi-esp32-server` is the self-hosted ASR/LLM/TTS service. XiaoClaw is no longer part of this branch; `dependencies/patches/xiaoclaw/0001-fix-lamp-controller-conflict.patch` stays only as a historical reference and is applied by no script.

The BuddyCore repository records each submodule commit. ESP-IDF's nested source submodules are initialized recursively. `xiaozhi-esp32` resolves its own components through the ESP-IDF Component Manager (`main/idf_component.yml`); generated `managed_components/`, `build/`, `releases/` and `sdkconfig*` content inside that checkout is ignored by the upstream repository. `xiaozhi-esp32-server` holds `main/xiaozhi-server` (Python), `main/manager-api` (Java), `main/manager-web` and `main/manager-mobile`; it is deployed separately and is not part of the ESP-IDF build.

Project-owned patches are grouped by upstream dependency in `patches/<dependency>/`, and the submodule checkouts stay pristine. For the server, `patches/xiaozhi-esp32-server/` holds five patches: `0001-huoshan-tts-api-key-auth.patch` and `0002-huoshan-asr-api-key-auth.patch` teach the Doubao TTS and ASR providers the newer single-key auth (`X-Api-Key`); `0003-buddycore-wakeup-reply-text.patch` pins the wake-word reply text; `0004-buddycore-activation-code-ws-gate.patch` and `0005-buddycore-activation-code-ota-gate.patch` add the device activation-code gate to the WebSocket handshake and the OTA response. `start-server.sh` applies them to copies under `build/server-overrides/`, which the compose file mounts over the corresponding container files.

Firmware changes live in `patches/xiaozhi-esp32/` and are applied to the tree that actually gets built — `build-xiaozhi-baseline.sh` copies the checkout under `build/xiaozhi-esp32/src/` first, the Windows script patches the short-path copy — skipping patches that are already applied and failing loudly when neither applying nor reverting works. `0001-buddycore-activation-code-report.patch` makes the device report the activation code in the OTA and WebSocket handshakes; `0002-buddycore-activation-code-provisioning-ui.patch` adds the field to the Wi-Fi provisioning page plus its NVS storage. That page lives in the `78__esp-wifi-connect` managed component, whose `managed_components/` directory is ignored by upstream, so the patch is the only place those files are ever modified. Board selection at this pin is a Kconfig choice, and generated `sdkconfig`/build output land under BuddyCore's ignored `build/`.

## Version choices

The project keeps ESP-IDF at `v5.5.5` and pins `xiaozhi-esp32` to `v2.3.0`, the newest upstream release whose mainline targets ESP-IDF 5.x: it declares `idf: version: '>=5.5.2'` and defaults to the `BREAD_COMPACT_WIFI` board. `v2.4.0` already moved the mainline to ESP-IDF 6.0 (5.5 is retained there only for legacy board paths), so moving `xiaozhi-esp32` forward again implies raising the `esp-idf` pin to a 6.0.x release and rerunning `./bootstrap-idf.sh`. That upgrade is deliberately deferred.

Because this pin predates `scripts/build.py`, the baseline build is plain `idf.py` driven by `build-xiaozhi-baseline.sh`: one board per build directory, selected through the `CONFIG_BOARD_TYPE_*` Kconfig choice (upstream default `BREAD_COMPACT_WIFI`, mapped to `main/boards/bread-compact-wifi`), with `-DBOARD_NAME=<board>` supplying the device identity macro that upstream's own release flow passes.

Local compiler/tool downloads and Python environments live under `dependencies/.espressif/`; optional host-only build utilities live under `dependencies/.host-tools/`. Both are ignored because they are platform-specific generated binaries. Do not commit toolchains, component caches, sdkconfig files containing credentials, or firmware build output.

`xiaozhi-esp32` and `xiaozhi-esp32-server` are MIT-licensed; ESP-IDF is Apache-2.0-licensed. Review the upstream license files before redistribution.

Update dependencies deliberately, one at a time. After changing a submodule commit, rerun the host baseline build, inspect upstream build assumptions and licenses, and update this table plus `docs/deployment/local-development.md`.
