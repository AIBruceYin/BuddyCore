# Service Deployment Boundaries

The device deployment sequence and hardware safety checks are in [ESP32-S3 Deployment](esp32-s3.md).

## First Release

Branch `xiaozhiAI` owns both ends of the voice path: the pinned xiaozhi-esp32 firmware talks to the self-hosted xiaozhi-esp32-server, which runs ASR, the agent/LLM call and TTS. Deploying that service (its Python `main/xiaozhi-server`, the Java manager API and web frontends, or the upstream Docker images) is now a BuddyCore responsibility; record the chosen host, endpoints, accounts and TLS setup here once they are confirmed. Do not silently point the device at an unknown endpoint, and keep credentials, tokens and access-controlled URLs out of this repository.

For the current test phase the service runs on the project owner's local machine, and the cloud LLM it calls is that owner's account: request the endpoint, account and key from them instead of committing any of it here. Non-secret shape only — host/port layout, which component holds the LLM configuration, and where secrets are injected.

The LLM endpoint is configured inside xiaozhi-esp32-server rather than on the device. For host development, the current machine has an OpenAI-compatible vLLM service at `http://127.0.0.1:8002/v1/chat/completions` exposing model `qwen3.5-2b`. The text/persona request was tested. The server currently rejects `tool_choice: auto`; no tool-capable service contract is claimed yet.

The existing vLLM deployment listens on all interfaces and has no API authentication. Keep tests on loopback. Before any device or LAN exposure, use an authenticated, access-controlled endpoint or a secured reverse proxy. Do not store secrets in this repository.

## Later Options

If local ASR/TTS or a different LLM pipeline is required, create a separately scoped implementation decision. Any change must keep compatibility with the protocol xiaozhi-esp32 speaks: WebSocket `hello` and MQTT/UDP transports, Opus audio frames, server-side ASR/agent/TTS events, TLS and interruption behavior. RTX 4090 ASR/TTS deployment is not a first-release prerequisite.
