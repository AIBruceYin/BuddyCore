# Service Deployment Boundaries

The device deployment sequence and hardware safety checks are in [ESP32-S3 Deployment](esp32-s3.md).

## First Release

Branch `xiaozhiAI` owns both ends of the voice path: the pinned xiaozhi-esp32 firmware talks to the self-hosted xiaozhi-esp32-server, which runs ASR, the agent/LLM call and TTS. Deploying that service (its Python `main/xiaozhi-server`, the Java manager API and web frontends, or the upstream Docker images) is now a BuddyCore responsibility; record the chosen host, endpoints, accounts and TLS setup here once they are confirmed. Do not silently point the device at an unknown endpoint, and keep credentials, tokens and access-controlled URLs out of this repository.

For the current test phase the service runs on the project owner's local machine, and the cloud LLM it calls is that owner's account: request the endpoint, account and key from them instead of committing any of it here. Non-secret shape only — host/port layout, which component holds the LLM configuration, and where secrets are injected.

## Server Deployment (Docker)

`xiaozhi-esp32-server` runs from BuddyCore through `./start-server.sh`, which renders the server config and drives `deploy/server/docker-compose.yml` (adapted from the pinned upstream `main/xiaozhi-server/docker-compose_all.yml`). Ports keep the upstream defaults: 8000 device WebSocket, 8003 server HTTP (single-service OTA and vision analysis), 8002 console and OTA gateway.

| Command | Effect |
| --- | --- |
| `./start-server.sh up` | Generates `deploy/server/data/.config.yaml`, then starts the stack |
| `./start-server.sh config` | Regenerates only the server config, after editing `.env` |
| `./start-server.sh status` / `logs` / `pull` / `restart` / `down` | Inspect, follow, update, restart, stop |

Configuration and secrets live in `deploy/server/.env` (copy `deploy/server/.env.example`). That file, the generated `data/`, and the `mysql/`, `uploadfile/`, `models/` state directories under `deploy/server/` are git-ignored.

`MANAGER_SECRET` selects the mode:

* **Local mode (empty)** — only the main service runs; ports, `selected_module`, the LLM key and the persona prompt come from `config/server/xiaozhi-server.local.yaml.template`. Device OTA: `http://<host>:8003/xiaozhi/ota/`; WebSocket: `ws://<host>:8000/xiaozhi/v1/`.
* **Console mode (set)** — the web/db/redis containers start as well and the server pulls models, agents and prompts from the manager, so `config/server/xiaozhi-server.console.yaml.template` deliberately omits `selected_module` and the LLM key is entered in the console. OTA moves to `http://<host>:8002/xiaozhi/ota/`; get the secret from 参数管理 → `server.secret` after registering the first admin.

Model access status (2026-10-15): the LLM path is verified against Volcengine Ark (OpenAI-compatible, `https://ark.cn-beijing.volces.com/api/v3`). `doubao-seed-2-0-lite-260428` answers a chat request and returns a `tool_calls` response, which the server's default `Intent: function_call` requires. Model ids are account-specific: `GET /api/v3/models` reports a `status` per model (`Shutdown`, `Retiring`, or blank) and unavailable ids answer `404 InvalidEndpointOrModel.NotFound`. Upstream `config.yaml` still ships `doubao-seed-2-0-lite-260215`, which is `Retiring` in this account, so `.env` pins `260428` instead; check the status list before changing models.

Volcengine speech (ASR/TTS) is still open. This server version authenticates Doubao speech with `X-Api-App-Key` + `X-Api-Access-Key`, i.e. the speech app's `appid` plus `access_token`; neither the pinned commit nor current upstream `main` accepts the newer single speech API key. Those two values are therefore still needed before Doubao ASR/TTS can replace the key-free defaults (local FunASR plus EdgeTTS).

Cloud server: copy the repository, create `deploy/server/.env`, set `PUBLIC_HOST` to the public IP or domain, open 8000/8002/8003 in the security group, and run `./start-server.sh up`. State stays in `deploy/server/{data,mysql,uploadfile}`; pin the image tags instead of `*_latest` before production use.

The LLM endpoint is configured inside xiaozhi-esp32-server rather than on the device. For host development, the current machine has an OpenAI-compatible vLLM service at `http://127.0.0.1:8002/v1/chat/completions` exposing model `qwen3.5-2b`. The text/persona request was tested. The server currently rejects `tool_choice: auto`; no tool-capable service contract is claimed yet.

The existing vLLM deployment listens on all interfaces and has no API authentication. Keep tests on loopback. Before any device or LAN exposure, use an authenticated, access-controlled endpoint or a secured reverse proxy. Do not store secrets in this repository.

## Later Options

If local ASR/TTS or a different LLM pipeline is required, create a separately scoped implementation decision. Any change must keep compatibility with the protocol xiaozhi-esp32 speaks: WebSocket `hello` and MQTT/UDP transports, Opus audio frames, server-side ASR/agent/TTS events, TLS and interruption behavior. RTX 4090 ASR/TTS deployment is not a first-release prerequisite.
