# System Architecture

## Ownership

```text
BuddyCore
|-- dependencies/xiaoclaw/  pinned firmware base
|-- dependencies/esp-idf/   pinned ESP-IDF source and nested components
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

The root Git repository pins XiaoClaw and ESP-IDF as submodules. Keep project-specific source changes as small patches under `dependencies/patches/<dependency>/`; do not edit a dependency checkout without recording the equivalent patch. Generated build output, credentials, model weights and tool binaries are not versioned.

## Runtime Flow

1. ESP-SR detects the wake word locally on the ESP32-S3.
2. XiaoClaw records audio, encodes Opus and sends it through its configured Xiaozhi WebSocket protocol.
3. The configured voice server performs ASR and returns an `stt` text event.
4. The Mimi Agent builds the persona prompt and sends a request to the configured OpenAI-compatible LLM API.
5. The Agent response returns through the bridge; XiaoClaw sends `tts_request` to the same voice session.
6. The voice server returns TTS audio; XiaoClaw decodes and plays it locally.

LLM HTTP and Xiaozhi voice transport are separate endpoints. The first release reuses XiaoClaw's existing voice-server configuration. It does not add a new ASR/TTS gateway. RTX 4090 currently serves only as an LLM development backend; deploying local ASR/TTS remains a separate future decision.

## Current Validation Boundary

Host tests validate the persona file and OpenAI-compatible request/response shape. The pinned XiaoClaw baseline cross-build validates source/toolchain compatibility under its default board assumptions. Neither test validates the selected physical board, network access to the configured voice server, microphone/speaker operation, or real-time speech latency.