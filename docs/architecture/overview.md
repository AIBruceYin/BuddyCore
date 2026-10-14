# System Architecture

## Ownership

```text
BuddyCore
|-- dependencies/xiaozhi-esp32/         pinned firmware base
|-- dependencies/xiaozhi-esp32-server/  pinned ASR/LLM/TTS service source
|-- dependencies/esp-idf/               pinned ESP-IDF source and nested components
|-- firmware/               BuddyCore sdkconfig overlays and upstream patches
|-- persona/                persona prompt source
|-- services/               host-side API contract probes
|-- tests/                  host-only contract tests
|-- *.sh                    root-level dependency setup, environment, test and build entry points
|-- docs/                   architecture, decisions and development instructions
|-- deploy/                 service ownership and deployment notes
|-- build/                  ignored generated output
`-- dependencies/.espressif/ ignored ESP-IDF tools and Python environment
```

The root Git repository pins xiaozhi-esp32, xiaozhi-esp32-server and ESP-IDF as submodules. Branch `xiaozhiAI` replaces the former XiaoClaw firmware base with xiaozhi-esp32 and adds the self-hosted service. Keep project-specific source changes as small patches under `dependencies/patches/<dependency>/`; do not edit a dependency checkout without recording the equivalent patch. Generated build output, credentials, model weights and tool binaries are not versioned.

## Runtime Flow

1. ESP-SR detects the wake word locally on the ESP32-S3.
2. xiaozhi-esp32 records audio, encodes Opus and sends it over its WebSocket or MQTT/UDP protocol.
3. xiaozhi-esp32-server performs ASR and returns the recognised text to the device.
4. The server-side agent builds the persona prompt and calls the configured OpenAI-compatible LLM API.
5. The server synthesises TTS audio and streams it back over the same session.
6. xiaozhi-esp32 decodes the returned audio and plays it locally.

The ASR, LLM and TTS stages all live in the self-hosted xiaozhi-esp32-server deployment; the device keeps wake-word detection, Opus encode/decode, display state and playback. RTX 4090 currently serves only as an LLM development backend; deploying local ASR/TTS remains a separate future decision.

## Current Validation Boundary

Host tests validate the persona file and OpenAI-compatible request/response shape. The pinned xiaozhi-esp32 v2.3.0 baseline cross-build validates source/toolchain compatibility for the upstream default board against the pinned ESP-IDF v5.5.5, which satisfies that release's `>=5.5.2` requirement. Neither test validates the selected physical board, network access to the voice server, microphone/speaker operation, or real-time speech latency.
