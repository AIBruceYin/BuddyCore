# Service Deployment Boundaries

The device deployment sequence and hardware safety checks are in [ESP32-S3 Deployment](esp32-s3.md).

## First Release

BuddyCore does not deploy a speech gateway in the first release. XiaoClaw uses the voice server provided by its current OTA/WebSocket configuration for ASR and TTS. Confirm the endpoint, test account, network reachability and TLS certificate with the service owner before device testing; do not silently replace a configured production endpoint.

The LLM endpoint is independent. For host development, the current machine has an OpenAI-compatible vLLM service at `http://127.0.0.1:8002/v1/chat/completions` exposing model `qwen3.5-2b`. The text/persona request was tested. The server currently rejects `tool_choice: auto`; no tool-capable service contract is claimed yet.

The existing vLLM deployment listens on all interfaces and has no API authentication. Keep tests on loopback. Before any device or LAN exposure, use an authenticated, access-controlled endpoint or a secured reverse proxy. Do not store secrets in this repository.

## Later Options

If the configured voice server becomes unavailable or local ASR/TTS is required, create a separately scoped implementation decision. It must establish protocol compatibility with XiaoClaw's WebSocket `hello`, Opus audio, `stt`, `tts_request`, TTS state/audio events, TLS and interruption behavior before any firmware change. RTX 4090 ASR/TTS deployment is not a first-release prerequisite.