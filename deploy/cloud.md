# 云端部署（xiaozhi-esp32-server）

目标：语音/LLM 服务跑在公网云主机，ESP32-S3 设备经 HTTPS/WSS 接入。

## 形态选择

| 形态 | 适用 | 对外端口 | 设备侧地址 |
| --- | --- | --- | --- |
| `cloud`（域名 + TLS） | 有域名、长期运行 | 80、443（Caddy 自动申请证书） | `https://<域名>/xiaozhi/ota/`、`wss://<域名>/xiaozhi/v1/` |
| `local`（公网 IP + 明文） | 无域名、临时测试 | 8000、8003（+8002 智控台） | `http://<IP>:8003/xiaozhi/ota/`、`ws://<IP>:8000/xiaozhi/v1/` |

## 前置条件（cloud 形态）

- Ubuntu 22.04+/Debian 12，Docker Engine + Compose **≥ 2.24**（云叠加用到 `!reset`）
- 域名的 A 记录指向主机公网 IP
- 安全组/防火墙放行 80、443（若还要用智控台，另放行 443 上的 `/xiaozhi/ota/` 即可）
- 仓库已就位，且 `dependencies/xiaozhi-esp32-server` 子模块可用（补丁锚点）

## 部署步骤

```bash
git clone <repo> && cd BuddyCore
git submodule update --init dependencies/xiaozhi-esp32-server

cp deploy/server/.env.example deploy/server/.env
# 需要填：BUDDYCORE_STACK=cloud、PUBLIC_HOST=<域名>、ARK_API_KEY、SPEECH_API_KEY、
#        VOLC_TTS_RESOURCE_ID/VOLC_TTS_VOICE、VOLC_ASR_RESOURCE_ID、
#        MYSQL_ROOT_PASSWORD（务必改掉示例值）、可选 ACME_EMAIL

./start-server.sh up      # 首次会拉镜像、生成 data/.config.yaml、物化两个补丁覆盖文件
./start-server.sh check    # 自检：docker/配置渲染/容器状态/OTA 可达性
```

## 验证

```bash
curl -fsS https://<域名>/xiaozhi/ota/      # 期望返回含 wss://<域名>/xiaozhi/v1/ 的文本
docker logs --tail 50 buddycore-caddy      # 看证书签发与请求日志
./start-server.sh status
```

设备侧：固件的 OTA 地址由 `CONFIG_OTA_URL` 编进固件，联网到公网需重新编译烧录为
`https://<域名>/xiaozhi/ota/`；`config/firmware/sdkconfig.buddycore-s3-touch-lcd-1.85c.defaults`
配合 `build-xiaozhi-baseline.ps1` 的可覆盖项即可，只改这一行配置。

可选：把本机已经生成的唤醒应答（`deploy/server/data/wakeup_words/<音色md5>.wav` 与
`data/.wakeup_words.yaml`）一起拷到云端，这样首次唤醒就是复刻音色；不放也可以，
服务端会在第一次唤醒后用配置的音色重新生成并缓存。

## 运维

- 日志：`./start-server.sh logs`（主服务）、`docker logs -f buddycore-caddy`（入口）
- 更新：`git pull && ./start-server.sh pull && ./start-server.sh up`
- 备份：`deploy/server/data/`（`.config.yaml`、`.wakeup_words.yaml`、唤醒应答缓存）
- 密钥：只存在于 `deploy/server/.env` 与 `deploy/server/data/.config.yaml`，不入库
- 卸载：`./start-server.sh down`（保留数据目录）

## 安全注意

- cloud 形态只对外暴露 80/443；云叠加已用 `!reset` 清掉 8000/8002/8003 的发布，不要再手工放开
- MySQL/Redis 只在编排内部网络（`expose`，不映射到宿主机）
- 建议云主机 `ufw` 只放行 22/80/443，并禁用密码登录、改用密钥
- 智控台模式（设了 `MANAGER_SECRET`）会额外启动 web/db/redis，并把 OTA 交给 web 容器；
  此时脚本会自动把 Caddy 的 OTA 上游指向 `xiaozhi-esp32-server-web:8002`
