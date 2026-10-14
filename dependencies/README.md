# Dependencies

Source dependencies are checked out inside this directory as Git submodules:

| Path | Upstream | Pinned revision |
| --- | --- | --- |
| `xiaozhi-esp32/` | https://github.com/78/xiaozhi-esp32 | commit `e076ac496e2d93dc3a2308a0491d745afe9489ab` (branch `main`, pinned 2026-10-14) |
| `xiaozhi-esp32-server/` | https://github.com/xinnan-tech/xiaozhi-esp32-server | commit `27399a2fb64b5910196f438a256ce0a9f868481f` (branch `main`, pinned 2026-10-14) |
| `esp-idf/` | https://github.com/espressif/esp-idf | commit `b774170ff46c393eeb5e495ea37936038d3f4f4f` (ESP-IDF `v5.5.5`) |

Branch `xiaozhiAI` builds on XiaoZhi instead of XiaoClaw: `xiaozhi-esp32` is the device firmware base and `xiaozhi-esp32-server` is the self-hosted ASR/LLM/TTS service. XiaoClaw is no longer part of this branch; `dependencies/patches/xiaoclaw/0001-fix-lamp-controller-conflict.patch` stays only as a historical reference and is applied by no script.

The BuddyCore repository records each submodule commit. ESP-IDF's nested source submodules are initialized recursively. `xiaozhi-esp32` resolves its own components through the ESP-IDF Component Manager (`main/idf_component.yml`); generated `managed_components/`, `build/`, `releases/` and `sdkconfig*` content inside that checkout is ignored by the upstream repository. `xiaozhi-esp32-server` holds `main/xiaozhi-server` (Python), `main/manager-api` (Java), `main/manager-web` and `main/manager-mobile`; it is deployed separately and is not part of the ESP-IDF build.

Project-owned patches are grouped by upstream dependency in `patches/<dependency>/`. A baseline build runs the upstream checkout directly and does not modify it.

## Version constraint (open decision)

`xiaozhi-esp32` currently requires **ESP-IDF >= 6.0.1**: `scripts/build.py` defaults to IDF 6.0.2 and upstream states that IDF 5.x is not supported. The `esp-idf` submodule still pins `v5.5.5`, so a `xiaozhi-esp32` firmware build cannot succeed until either the IDF pin is raised or `xiaozhi-esp32` is pinned to an older IDF-5.x-compatible release. Decide this before building or flashing.

Local compiler/tool downloads and Python environments live under `dependencies/.espressif/`; optional host-only build utilities live under `dependencies/.host-tools/`. Both are ignored because they are platform-specific generated binaries. Do not commit toolchains, component caches, sdkconfig files containing credentials, or firmware build output.

`xiaozhi-esp32` and `xiaozhi-esp32-server` are MIT-licensed; ESP-IDF is Apache-2.0-licensed. Review the upstream license files before redistribution.

Update dependencies deliberately, one at a time. After changing a submodule commit, rerun the host baseline build, inspect upstream build assumptions and licenses, and update this table plus `docs/deployment/local-development.md`.
