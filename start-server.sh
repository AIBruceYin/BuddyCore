#!/usr/bin/env bash
set -euo pipefail

# BuddyCore 小智服务端（xiaozhi-esp32-server）启动脚本。
# 本地测试和云服务器共用一套流程：没有交互式提问，所有可变项都来自
# deploy/server/.env（模板见 deploy/server/.env.example，真实值不进仓库）。
#
#   ./start-server.sh up        启动服务（按 .env 决定是否包含智控台）
#   ./start-server.sh config    仅重新生成 data/.config.yaml（改了 .env 后执行）
#   ./start-server.sh overrides 仅重新生成上游补丁的覆盖文件（build/server-overrides/）
#   ./start-server.sh check     部署自检（docker/.env/配置渲染/容器状态/OTA 可达性）
#   ./start-server.sh status    查看容器状态与访问地址
#   ./start-server.sh logs      跟随主服务日志
#   ./start-server.sh pull      拉取/更新镜像
#   ./start-server.sh restart   重启容器
#   ./start-server.sh down      停止并删除容器（保留 data/ 与 mysql/ 数据）
#
# 生成物：deploy/server/data/.config.yaml（含密钥，已被 .gitignore 忽略）

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$ROOT/deploy/server"
ENV_FILE="$SERVER_DIR/.env"
COMPOSE_FILE="$SERVER_DIR/docker-compose.yml"
TEMPLATE_LOCAL="$ROOT/config/server/xiaozhi-server.local.yaml.template"
TEMPLATE_CONSOLE="$ROOT/config/server/xiaozhi-server.console.yaml.template"
GENERATED_CONFIG="$SERVER_DIR/data/.config.yaml"
MODEL_FILE="$SERVER_DIR/models/SenseVoiceSmall/model.pt"
SERVER_SUB="$ROOT/dependencies/xiaozhi-esp32-server"
# 上游补丁 → 子模块内文件 → 生成到 build/ 的覆盖文件（compose 以只读方式挂进容器）
SERVER_PATCHES=(
  "dependencies/patches/xiaozhi-esp32-server/0001-huoshan-tts-api-key-auth.patch|main/xiaozhi-server/core/providers/tts/huoshan_double_stream.py|build/server-overrides/core/providers/tts/huoshan_double_stream.py"
  "dependencies/patches/xiaozhi-esp32-server/0002-huoshan-asr-api-key-auth.patch|main/xiaozhi-server/core/providers/asr/doubao_stream.py|build/server-overrides/core/providers/asr/doubao_stream.py"
  "dependencies/patches/xiaozhi-esp32-server/0003-buddycore-wakeup-reply-text.patch|main/xiaozhi-server/core/handle/helloHandle.py|build/server-overrides/core/handle/helloHandle.py"
)

usage() {
  cat <<'EOF'
用法：./start-server.sh <命令>

  up        启动服务（按 deploy/server/.env 决定是否包含智控台）
  config    仅重新生成 deploy/server/data/.config.yaml
  overrides 仅重新生成上游补丁的覆盖文件（build/server-overrides/）
  check     部署自检：docker、.env、配置渲染、容器状态、OTA 可达性
  status    查看容器状态与访问地址
  logs      跟随主服务日志
  pull      拉取/更新镜像
  restart   重启容器
  down      停止并删除容器（保留数据卷目录）
EOF
}

die() { echo "错误：$*" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || die "缺少 $ENV_FILE，请先复制 deploy/server/.env.example 并填写。"
[[ -f "$COMPOSE_FILE" ]] || die "缺少 $COMPOSE_FILE。"

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

PUBLIC_HOST="${PUBLIC_HOST:-127.0.0.1}"
PORT_WS="${PORT_WS:-8000}"
PORT_HTTP="${PORT_HTTP:-8003}"
PORT_CONSOLE="${PORT_CONSOLE:-8002}"
MANAGER_API_URL="${MANAGER_API_URL:-http://xiaozhi-esp32-server-web:8002/xiaozhi}"
STACK="${BUDDYCORE_STACK:-local}"

# 设备侧实际使用的地址：cloud 栈走域名 + HTTPS/WSS，local 栈走 IP + 端口
PUBLIC_SCHEME="${PUBLIC_SCHEME:-$([[ "$STACK" == "cloud" ]] && echo https || echo http)}"
if [[ "$PUBLIC_SCHEME" == "https" ]]; then
  PUBLIC_WS_URL="${PUBLIC_WS_URL:-wss://${PUBLIC_HOST}/xiaozhi/v1/}"
  PUBLIC_VISION_URL="${PUBLIC_VISION_URL:-https://${PUBLIC_HOST}/mcp/vision/explain}"
  PUBLIC_OTA_URL="${PUBLIC_OTA_URL:-https://${PUBLIC_HOST}/xiaozhi/ota/}"
else
  PUBLIC_WS_URL="${PUBLIC_WS_URL:-ws://${PUBLIC_HOST}:${PORT_WS}/xiaozhi/v1/}"
  PUBLIC_VISION_URL="${PUBLIC_VISION_URL:-http://${PUBLIC_HOST}:${PORT_HTTP}/mcp/vision/explain}"
  PUBLIC_OTA_URL="${PUBLIC_OTA_URL:-http://${PUBLIC_HOST}:${PORT_HTTP}/xiaozhi/ota/}"
fi
export PUBLIC_SCHEME PUBLIC_WS_URL PUBLIC_VISION_URL PUBLIC_OTA_URL

PROFILE_ARGS=()
if [[ -n "${MANAGER_SECRET:-}" ]]; then
  PROFILE_ARGS=(--profile console)
fi

COMPOSE_FILES=(--file "$COMPOSE_FILE")
if [[ "$STACK" == "cloud" ]]; then
  [[ -f "$SERVER_DIR/docker-compose.cloud.yml" ]] || die "缺少 deploy/server/docker-compose.cloud.yml"
  COMPOSE_FILES+=(--file "$SERVER_DIR/docker-compose.cloud.yml")
  # 智控台模式下 OTA 由 web 容器提供，Caddy 的 OTA 上游要指向它
  if [[ -n "${MANAGER_SECRET:-}" ]]; then
    export CADDY_OTA_UPSTREAM="${CADDY_OTA_UPSTREAM:-xiaozhi-esp32-server-web:8002}"
  else
    export CADDY_OTA_UPSTREAM="${CADDY_OTA_UPSTREAM:-xiaozhi-esp32-server:8003}"
  fi
  echo "部署形态：cloud（域名 ${PUBLIC_HOST}，走 ${PUBLIC_SCHEME}，Caddy 终止 TLS）"
else
  echo "部署形态：local（${PUBLIC_HOST}，端口 ${PORT_WS}/${PORT_HTTP}）"
fi

compose() {
  docker compose --project-directory "$SERVER_DIR" "${COMPOSE_FILES[@]}" "$@"
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "未找到 docker，请先安装 Docker Engine 或 Docker Desktop。"
  docker compose version >/dev/null 2>&1 || die "当前 docker 不支持 'docker compose'（Compose V2）。"
}

render_template() {
  local template="$1" output="$2" line name value
  : > "$output"
  while IFS= read -r line || [[ -n "$line" ]]; do
    while [[ "$line" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
      name="${BASH_REMATCH[1]}"
      value="${!name-}"
      line="${line//\$\{${name}\}/${value}}"
    done
    printf '%s\n' "$line" >> "$output"
  done < "$template"
}

ensure_dirs() {
  mkdir -p "$SERVER_DIR/data" "$SERVER_DIR/uploadfile" "$SERVER_DIR/mysql/data" "$SERVER_DIR/models/SenseVoiceSmall"
}

ensure_sensevoice_model() {
  mkdir -p "$(dirname "$MODEL_FILE")"
  [[ -s "$MODEL_FILE" ]] && return 0
  if [[ "${DOWNLOAD_SENSEVOICE_MODEL:-1}" != "1" ]]; then
    echo "提示：跳过 SenseVoice 模型下载；如不使用 SenseVoice ASR 可忽略，否则请手动放置 $MODEL_FILE"
    : > "$MODEL_FILE"
    return 0
  fi
  command -v curl >/dev/null 2>&1 || die "缺少 curl，无法下载 SenseVoice 模型；可手动下载到 $MODEL_FILE 或设置 DOWNLOAD_SENSEVOICE_MODEL=0。"
  echo "下载 SenseVoice 模型（首次较慢，约 200MB）→ $MODEL_FILE"
  if ! curl -fL --progress-bar "${SENSEVOICE_MODEL_URL}" -o "$MODEL_FILE"; then
    rm -f "$MODEL_FILE"
    die "SenseVoice 模型下载失败：可手动下载 ${SENSEVOICE_MODEL_URL} 到 $MODEL_FILE，或设置 DOWNLOAD_SENSEVOICE_MODEL=0 跳过。"
  fi
}

warn_missing_cloud_voice() {
  local module_name="$1" module_value="$2" has_new=0 has_old=0
  case "$module_value" in
    Doubao*|Huoshan*) ;;
    *) return 0 ;;
  esac
  [[ -n "${SPEECH_API_KEY:-}" ]] && has_new=1
  [[ -n "${VOLC_APPID:-}" && -n "${VOLC_ACCESS_TOKEN:-}" ]] && has_old=1
  if [[ "$module_name" == "TTS" ]]; then
    [[ $has_new -eq 1 || $has_old -eq 1 ]] || \
      echo "警告：TTS=${module_value} 需要 SPEECH_API_KEY（新版）或 appid+access_token（旧版），当前都为空。" >&2
  else
    [[ $has_new -eq 1 || $has_old -eq 1 ]] || \
      echo "警告：ASR=${module_value} 需要 SPEECH_API_KEY（新版，配 volc.seedasr.sauc.duration）或 appid+access_token（旧版），当前都为空。" >&2
  fi
}

ensure_server_overrides() {
  local entry patch target out rest
  for entry in "${SERVER_PATCHES[@]}"; do
    patch="$ROOT/${entry%%|*}"
    rest="${entry#*|}"
    target="${rest%%|*}"
    out="$ROOT/${rest#*|}"
    # 云主机等只带部署产物、没有 dependencies/ 子模块源码的场景：
    # 覆盖文件已生成过就直接复用，不必再物化补丁。
    if [[ ! -e "$SERVER_SUB/.git" && -f "$out" ]]; then
      echo "跳过补丁物化（主机上没有子模块源码），使用已有覆盖文件：${out#"$ROOT"/}"
      continue
    fi
    [[ -f "$patch" ]] || die "缺少服务端补丁：$patch"
    if [[ -n "$(git -C "$SERVER_SUB" status --porcelain -- "$target")" ]]; then
      die "子模块里的 $target 有未提交改动，请先处理，避免被脚本覆盖。"
    fi
    if ! git -C "$SERVER_SUB" apply --check "$patch" >/dev/null 2>&1; then
      if git -C "$SERVER_SUB" apply --reverse --check "$patch" >/dev/null 2>&1; then
        die "服务端补丁已存在于子模块中，请先恢复 dependencies/xiaozhi-esp32-server 的干净状态：$patch"
      fi
      die "服务端补丁无法应用到当前子模块版本（可能升级过 xiaozhi-esp32-server）：$patch"
    fi
    mkdir -p "$(dirname "$out")"
    git -C "$SERVER_SUB" apply "$patch" || die "应用服务端补丁失败：$patch"
    cp "$SERVER_SUB/$target" "$out"
    git -C "$SERVER_SUB" checkout -- "$target"
    echo "已生成覆盖文件：${out#"$ROOT"/}"
  done
}

generate_config() {
  ensure_dirs
  if [[ -n "${MANAGER_SECRET:-}" ]]; then
    render_template "$TEMPLATE_CONSOLE" "$GENERATED_CONFIG"
    echo "配置模式：智控台（服务端从 $MANAGER_API_URL 拉取模型与智能体配置）"
    return 0
  fi

  render_template "$TEMPLATE_LOCAL" "$GENERATED_CONFIG"
  warn_missing_cloud_voice ASR "${ASR_MODULE:-FunASR}"
  warn_missing_cloud_voice TTS "${TTS_MODULE:-EdgeTTS}"

  if [[ -n "${SPEECH_API_KEY:-}" ]]; then
    {
      printf '\nTTS:\n'
      printf '  HuoshanDoubleStreamTTS:\n    type: huoshan_double_stream\n    ws_url: wss://openspeech.bytedance.com/api/v3/tts/bidirection\n    api_key: %s\n    resource_id: %s\n    speaker: %s\n    enable_ws_reuse: True\n    output_dir: tmp/\n' \
        "$SPEECH_API_KEY" "${VOLC_TTS_RESOURCE_ID:-seed-tts-2.0}" "${VOLC_TTS_VOICE:-zh_female_gaolengyujie_uranus_bigtts}"
      printf '\nASR:\n'
      printf '  DoubaoStreamASRV2:\n    type: doubao_stream\n    api_key: %s\n    resource_id: %s\n    output_dir: tmp/\n' \
        "$SPEECH_API_KEY" "${VOLC_ASR_RESOURCE_ID:-volc.seedasr.sauc.duration}"
    } >> "$GENERATED_CONFIG"
    echo "已写入豆包 TTS/ASR（新版 API Key 鉴权）：TTS 资源 ${VOLC_TTS_RESOURCE_ID:-seed-tts-2.0} / 音色 ${VOLC_TTS_VOICE:-zh_female_gaolengyujie_uranus_bigtts}；ASR 资源 ${VOLC_ASR_RESOURCE_ID:-volc.seedasr.sauc.duration}"
  elif [[ -n "${VOLC_APPID:-}" && -n "${VOLC_ACCESS_TOKEN:-}" ]]; then
    {
      printf '\nTTS:\n'
      printf '  HuoshanDoubleStreamTTS:\n    type: huoshan_double_stream\n    ws_url: wss://openspeech.bytedance.com/api/v3/tts/bidirection\n    appid: %s\n    access_token: %s\n    resource_id: %s\n    speaker: %s\n    enable_ws_reuse: True\n    output_dir: tmp/\n' \
        "$VOLC_APPID" "$VOLC_ACCESS_TOKEN" "${VOLC_TTS_RESOURCE_ID:-volc.service_type.10029}" "${VOLC_TTS_VOICE:-zh_female_wanwanxiaohe_moon_bigtts}"
      printf '\nASR:\n'
      printf '  DoubaoStreamASRV2:\n    type: doubao_stream\n    appid: %s\n    access_token: %s\n    resource_id: volc.seedasr.sauc.duration\n    output_dir: tmp/\n' \
        "$VOLC_APPID" "$VOLC_ACCESS_TOKEN"
    } >> "$GENERATED_CONFIG"
    echo "已写入豆包语音（旧版 appid/access_token）：TTS/ASR 都可用，把 ASR_MODULE/TTS_MODULE 改成对应名称即可。"
  fi

  if [[ -n "${PERSONA_FILE:-}" && -f "$ROOT/${PERSONA_FILE}" ]]; then
    {
      printf '\n# 人格提示词来自 %s\nprompt: |\n' "$PERSONA_FILE"
      sed 's/^/  /' "$ROOT/${PERSONA_FILE}"
    } >> "$GENERATED_CONFIG"
    echo "已注入人格提示词：${PERSONA_FILE}"
  fi

  chmod 600 "$GENERATED_CONFIG" 2>/dev/null || true
  echo "配置模式：本地配置（未设置 MANAGER_SECRET，不使用智控台）"
}

run_check() {
  echo "=== 1) 运行环境 ==="
  command -v docker >/dev/null 2>&1 || die "未找到 docker"
  echo "docker:  $(docker --version)"
  docker compose version >/dev/null 2>&1 || die "缺少 docker compose V2"
  echo "compose: $(docker compose version --short)"
  docker info >/dev/null 2>&1 && echo "引擎:    可用" || die "docker 引擎不可用"

  echo "=== 2) 配置 ==="
  echo ".env:    存在（$(grep -c . "$ENV_FILE") 行）"
  [[ -n "${ARK_API_KEY:-}" ]] && echo "ARK_API_KEY:      已设置" || echo "ARK_API_KEY:      未设置"
  [[ -n "${SPEECH_API_KEY:-}" ]] && echo "SPEECH_API_KEY:   已设置" || echo "SPEECH_API_KEY:   未设置（语音会退回默认实现）"
  [[ -n "${MANAGER_SECRET:-}" ]] && echo "智控台:  开启（profile console）" || echo "智控台:  关闭（轻量单服务）"
  echo "部署形态: $STACK"
  echo "设备 OTA: $PUBLIC_OTA_URL"
  echo "设备 WS:  $PUBLIC_WS_URL"

  echo "=== 3) 配置渲染 ==="
  generate_config >/dev/null && echo "data/.config.yaml: 生成成功"

  echo "=== 4) 容器状态 ==="
  compose "${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}" ps

  echo "=== 5) OTA 接口可达性（本机探测） ==="
  local probe_url="$PUBLIC_OTA_URL"
  # cloud 栈的域名在本机可能尚未解析，探测时改用容器发布端口
  if [[ "$STACK" == "cloud" ]]; then probe_url="http://127.0.0.1:${PORT_HTTP}/xiaozhi/ota/"; fi
  if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 8 "$probe_url" >/dev/null 2>&1; then
    echo "可访问：$probe_url"
  else
    echo "暂时不可访问：$probe_url（服务未启动、或端口未放行/未映射）"
  fi

  if [[ "$STACK" == "cloud" ]]; then
    echo "=== 6) 云端额外检查 ==="
    if getent hosts "$PUBLIC_HOST" >/dev/null 2>&1; then
      echo "DNS: $PUBLIC_HOST 可解析"
    else
      echo "DNS: 本机无法解析 $PUBLIC_HOST —— 请确认 A 记录指向本机公网 IP"
    fi
    echo "安全组/防火墙：需放行 80 与 443（TLS 模式）"
  fi
}

print_endpoints() {
  echo "----------------------------------------"
  if [[ -n "${MANAGER_SECRET:-}" ]]; then
    if [[ "$PUBLIC_SCHEME" == "https" ]]; then
      echo "智控台 / OTA 网关：https://${PUBLIC_HOST}/"
    else
      echo "智控台 / OTA 网关：http://${PUBLIC_HOST}:${PORT_CONSOLE}/"
    fi
    echo "设备 OTA 地址：   ${PUBLIC_OTA_URL}"
    echo "首次使用：打开智控台注册管理员 → 参数管理 → server.secret → 填入 .env 的 MANAGER_SECRET 后重跑 ./start-server.sh config"
  else
    echo "设备 OTA 地址（单服务）：${PUBLIC_OTA_URL}"
  fi
  echo "设备 WebSocket：  ${PUBLIC_WS_URL}"
  echo "----------------------------------------"
}

cmd="${1:-up}"
case "$cmd" in
  up)
    require_docker
    ensure_dirs
    ensure_sensevoice_model
    ensure_server_overrides
    generate_config
    compose "${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}" up -d
    compose "${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}" ps
    print_endpoints
    ;;
  config)
    generate_config
    echo "如容器已在运行，执行 ./start-server.sh restart 使新配置生效。"
    ;;
  overrides)
    ensure_server_overrides
    echo "如容器已在运行，执行 ./start-server.sh restart 使新文件生效。"
    ;;
  check)
    require_docker
    run_check
    ;;
  status)
    require_docker
    compose "${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}" ps
    print_endpoints
    ;;
  logs)
    require_docker
    compose logs -f --tail=100 xiaozhi-esp32-server
    ;;
  pull)
    require_docker
    compose "${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}" pull
    ;;
  restart)
    require_docker
    compose "${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}" restart
    ;;
  down)
    require_docker
    compose "${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}" down
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    usage
    die "未知命令：$cmd"
    ;;
esac
