# Service Deployment Boundaries

The device deployment sequence and hardware safety checks are in [ESP32-S3 Deployment](esp32-s3.md).

## First Release

Branch `xiaozhiAI` owns both ends of the voice path: the pinned xiaozhi-esp32 firmware talks to the self-hosted xiaozhi-esp32-server, which runs ASR, the agent/LLM call and TTS. Deploying that service (its Python `main/xiaozhi-server`, the Java manager API and web frontends, or the upstream Docker images) is now a BuddyCore responsibility; record the chosen host, endpoints, accounts and TLS setup here once they are confirmed. Do not silently point the device at an unknown endpoint, and keep credentials, tokens and access-controlled URLs out of this repository.

For the current test phase the service runs on the project owner's local machine, and the cloud LLM it calls is that owner's account: request the endpoint, account and key from them instead of committing any of it here. Non-secret shape only — host/port layout, which component holds the LLM configuration, and where secrets are injected.

## Server Deployment (Docker)

Cloud hosts (public domain, HTTPS/WSS, only 80/443 exposed): see [Cloud Deployment](cloud.md) and set `BUDDYCORE_STACK=cloud`; the rest of this section describes the local/LAN stack.

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

Volcengine speech, TTS: works with the newer single-key console credential. `dependencies/patches/xiaozhi-esp32-server/0001-huoshan-tts-api-key-auth.patch` teaches the pinned provider to send `X-Api-Key` + `X-Api-Resource-Id` whenever `api_key` is configured, keeping the legacy `appid`/`access_token` path otherwise. `start-server.sh` applies that patch to a generated copy under `build/server-overrides/`, which the compose file mounts read-only over the upstream image, so the submodule stays pristine and the image is untouched. Verified against the live service on 2026-10-15: resource `seed-tts-2.0` with a `*_uranus_bigtts` voice returns PCM audio (about 190 KB for one short sentence). Resource and voice must be paired — resource `volc.service_type.10029` (e.g. 湾湾小何) answers HTTP 403 with this key.

Volcengine speech, ASR: works with the same single key. `dependencies/patches/xiaozhi-esp32-server/0002-huoshan-asr-api-key-auth.patch` adds `X-Api-Key` + `X-Api-Resource-Id` + `X-Api-Request-Id` to the streaming ASR provider and drops the `app`/`appid`/`token` block from the request body, which the current [bidirectional streaming ASR API](https://docs.volcengine.com/docs/DoubaoVoice/bidirectional-streaming-automatic-speech-recognition-websocket) no longer takes. Verified on 2026-10-15 through the provider's own protocol code with a 16 kHz PCM clip: resource `volc.seedasr.sauc.duration` (ASR 2.0) returns incremental results ending in 很高兴见到你。 Resource `volc.bigasr.sauc.duration` (ASR 1.0) answers HTTP 403 for this key, so use the 2.0 resource.

Custom cloned voices: the official TTS doc lists a second resource id for them — `seed-icl-2.0` (豆包声音复刻大模型2.0) — and that is the one to use. Verified on 2026-10-15: `seed-icl-2.0` with the cloned voice `S_1Q9BPMqh2` (resource project `buddycore`, display name `Lisa.beck`) returns PCM audio (16 kHz request, ~108 KB for one sentence), and feeding that audio back through the ASR provider transcribes it as 你好，我是丽莎。备课。 — the name 贝克 comes back as the homophone 备课, otherwise the round trip matches. `req_params.model` can stay at its default (`seed-tts-2.0-standard` also works; `seed-icl-2.0-standard` is rejected as `InvalidModel`). The older `volc.megatts.voiceclone` resource still handshakes but answers `45000292 quota exceeded for types: concurrency`, so it is not usable for this account. `start-server.sh` therefore defaults to `VOLC_TTS_RESOURCE_ID=seed-icl-2.0` with `VOLC_TTS_VOICE=S_1Q9BPMqh2`, and the `*_uranus_bigtts` preset voices remain the fallback. The TTS patch also treats `seed-icl-2.0` as a 2.0-family resource so the audio queue markers come from the audio stream rather than `SentenceStart` events.

Cloud server: copy the repository, create `deploy/server/.env`, set `PUBLIC_HOST` to the public IP or domain, open 8000/8002/8003 in the security group, and run `./start-server.sh up`. State stays in `deploy/server/{data,mysql,uploadfile}`; pin the image tags instead of `*_latest` before production use.

## Wake-Word Reply

When the recognised wake-word text matches `wakeup_words` in the server config (the local template lists `你好小智`, `你好Lisa`, `你好丽莎`, `你好丽萨`), the server answers with a cached clip: `config/assets/wakeup_words/<md5(speaker)>.wav`, registered in `data/.wakeup_words.yaml`. The compose file mounts `deploy/server/data/wakeup_words/` over that directory so the clip survives container restarts.

Without a pre-generated clip the first wake plays the upstream factory-voice file (`config/assets/wakeup_words_short.wav`, "我在这里哦！") while the server generates a replacement in the configured voice in the background. For the cloned voice `S_1Q9BPMqh2` a clip saying 我在呢，今天想聊点什么？ is pre-generated (md5 of the speaker id is `7d68eedf8767efc893c257b73b63d653`), so the very first wake already answers in the cloned voice.

The LLM endpoint is configured inside xiaozhi-esp32-server rather than on the device. For host development, the current machine has an OpenAI-compatible vLLM service at `http://127.0.0.1:8002/v1/chat/completions` exposing model `qwen3.5-2b`. The text/persona request was tested. The server currently rejects `tool_choice: auto`; no tool-capable service contract is claimed yet.

The existing vLLM deployment listens on all interfaces and has no API authentication. Keep tests on loopback. Before any device or LAN exposure, use an authenticated, access-controlled endpoint or a secured reverse proxy. Do not store secrets in this repository.

## Later Options

If local ASR/TTS or a different LLM pipeline is required, create a separately scoped implementation decision. Any change must keep compatibility with the protocol xiaozhi-esp32 speaks: WebSocket `hello` and MQTT/UDP transports, Opus audio frames, server-side ASR/agent/TTS events, TLS and interruption behavior. RTX 4090 ASR/TTS deployment is not a first-release prerequisite.
