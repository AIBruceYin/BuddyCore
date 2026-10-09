# Project Configuration

This directory is the tracked source of BuddyCore-owned runtime and build configuration. The project implementation plan lives separately in [`docs/plan.md`](../docs/plan.md). Object-specific runtime settings live in a matching subdirectory so multiple task objects can coexist.

| File | Purpose | Secret data allowed? |
| --- | --- | --- |
| `<ObjectName>/SOUL.md` | Object-specific persona prompt intended for XiaoClaw's `/fatfs/config/SOUL.md`; Lisa's is `Lisa.Beck/SOUL.md` | No |
| `firmware/sdkconfig.host.defaults` | Non-secret LVGL/C++ options needed for the host XiaoClaw baseline build | No |
Keep each task object's persona and future runtime settings together in `config/<ObjectName>/`. Project-wide ESP-IDF defaults remain at the top level. Do not put Wi-Fi credentials, API tokens, production URLs that are access-controlled, or device identifiers in tracked defaults. XiaoClaw's `sdkconfig` is generated under ignored `build/`; runtime secrets should be entered through the appropriate local configuration or device provisioning process. Local environment files under this directory are ignored by Git.

The OTA-provided Xiaozhi voice-service address remains owned by the current XiaoClaw service configuration in the first release. Do not copy an unknown production endpoint or its credentials into this repository.