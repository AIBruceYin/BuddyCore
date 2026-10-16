#!/usr/bin/env bash
# 组装云端最小部署包（云主机没有 dependencies/ 子模块，只带预生成的补丁覆盖文件）
#
# 用法：./deploy/make-cloud-bundle.sh [输出目录]   # 默认 build/cloud-bundle
# 之后把输出目录整体 scp/rsync 到云主机（例如 /opt/buddycore）即可。
#
# 注意：一定要带上 config/<ObjectName>/（如 Lisa.Beck/SOUL.md），
# 否则 start-server.sh 找不到人格文件、云端会退回上游默认人设。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/build/cloud-bundle}"

if [[ -d "$OUT" && -n "$(ls -A "$OUT" 2>/dev/null)" ]]; then
  echo "提示：$OUT 已存在且非空，将直接覆盖同名文件（旧文件不会清理）。"
fi
mkdir -p "$OUT"

# 1) 根脚本 + 编排 + 文档
cp "$ROOT/start-server.sh" "$OUT/"
mkdir -p "$OUT/deploy/server"
cp "$ROOT/deploy/server/docker-compose.yml" \
   "$ROOT/deploy/server/docker-compose.cloud.yml" \
   "$ROOT/deploy/server/Caddyfile" \
   "$ROOT/deploy/server/.env.example" \
   "$OUT/deploy/server/"
[[ -f "$ROOT/deploy/cloud.md" ]] && cp "$ROOT/deploy/cloud.md" "$OUT/deploy/"

# 1b) 本地覆盖模块（compose 以只读方式挂进容器，必须跟着上云）
mkdir -p "$OUT/deploy/server/overrides"
cp -r "$ROOT/deploy/server/overrides/." "$OUT/deploy/server/overrides/"

# 2) 补丁覆盖文件（需先在本地跑过 ./start-server.sh overrides）
if [[ ! -d "$ROOT/build/server-overrides" ]]; then
  echo "缺少 build/server-overrides：请先运行 ./start-server.sh overrides" >&2
  exit 1
fi
mkdir -p "$OUT/build/server-overrides"
cp -r "$ROOT/build/server-overrides/." "$OUT/build/server-overrides/"
find "$OUT" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true

# 3) 配置模板 + 各任务对象目录（含人格 SOUL.md）
mkdir -p "$OUT/config"
cp -r "$ROOT/config/server" "$OUT/config/"
for d in "$ROOT"/config/*/; do
  name="$(basename "$d")"
  case "$name" in
    server|private) continue ;;
  esac
  mkdir -p "$OUT/config/$name"
  cp -r "$d." "$OUT/config/$name/"
done

# 4) 唤醒词应答缓存（可选：不带则首次唤醒用出厂音色，之后自动换成配置的音色）
mkdir -p "$OUT/deploy/server/data/wakeup_words"
[[ -f "$ROOT/deploy/server/data/activation_codes.txt" ]] && \
  cp "$ROOT/deploy/server/data/activation_codes.txt" "$OUT/deploy/server/data/"
[[ -f "$ROOT/deploy/server/data/.wakeup_words.yaml" ]] && \
  cp "$ROOT/deploy/server/data/.wakeup_words.yaml" "$OUT/deploy/server/data/"
cp "$ROOT/deploy/server/data/wakeup_words/"*.wav "$OUT/deploy/server/data/wakeup_words/" 2>/dev/null || true

echo "部署包已生成：$OUT"
find "$OUT" -type f | sed "s|^$OUT/||" | sort
