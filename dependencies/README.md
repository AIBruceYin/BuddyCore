# Dependencies

Source dependencies are checked out inside this directory as Git submodules:

| Path | Upstream | Pinned revision |
| --- | --- | --- |
| `xiaoclaw/` | https://github.com/beancookie/xiaoclaw | `55550bd461a5f760c256f59f32cbe2200a87e2c9` |
| `esp-idf/` | https://github.com/espressif/esp-idf | ESP-IDF `v5.5.5`, commit `b774170ff46c393eeb5e495ea37936038d3f4f4f` |

The BuddyCore repository records each submodule commit. ESP-IDF's nested source submodules are initialized recursively. XiaoClaw components declared through its component manifest are resolved by ESP-IDF Component Manager during build and appear under the XiaoClaw checkout as generated, ignored content.

Project-owned patches are grouped by upstream dependency in `patches/<dependency>/`. The XiaoClaw baseline build applies `patches/xiaoclaw/0001-fix-lamp-controller-conflict.patch` to an isolated worktree under ignored `build/`; the tracked `dependencies/xiaoclaw` submodule remains pristine.

Local compiler/tool downloads and Python environments live under `dependencies/.espressif/`; optional host-only build utilities live under `dependencies/.host-tools/`. Both are ignored because they are platform-specific generated binaries. Do not commit toolchains, component caches, sdkconfig files containing credentials, or firmware build output.

XiaoClaw is MIT-licensed; ESP-IDF is Apache-2.0-licensed. Review the upstream license files before redistribution.

Update dependencies deliberately, one at a time. After changing a submodule commit, rerun the host baseline build, inspect upstream build assumptions and licenses, and update this table plus `docs/deployment/local-development.md`.
