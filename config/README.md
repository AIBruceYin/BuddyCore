# Project Configuration

This directory is the tracked source of BuddyCore-owned runtime and build configuration. The project implementation plan lives separately in [`docs/plan.md`](../docs/plan.md). Object-specific runtime settings live in a matching subdirectory so multiple task objects can coexist.

| File | Purpose | Secret data allowed? |
| --- | --- | --- |
| `<ObjectName>/SOUL.md` | Object-specific persona prompt; source for the agent persona configured in xiaozhi-esp32-server. Lisa's is `Lisa.Beck/SOUL.md` | No |
| `firmware/sdkconfig.host.defaults` | Non-secret LVGL/C++ options for the BuddyCore validation build; not applied automatically by `build-xiaozhi-baseline.sh` yet | No |
Keep each task object's persona and future runtime settings together in `config/<ObjectName>/`. Project-wide build defaults remain at the top level. Do not put Wi-Fi credentials, API tokens, production URLs that are access-controlled, or device identifiers in tracked defaults. `./build-xiaozhi-baseline.sh` builds an upstream board variant whose sdkconfig defaults live in the xiaozhi-esp32 checkout; review `config/firmware/` when a BuddyCore-specific board or variant is added, and keep generated `sdkconfig` files inside ignored build output. Local environment files under this directory are ignored by Git.

The voice and LLM endpoints are owned by the self-hosted xiaozhi-esp32-server deployment instead of an upstream OTA configuration. Keep real endpoints, credentials and tokens out of this repository; record only the non-secret shape and where the value is configured.
