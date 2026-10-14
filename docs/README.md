# 方案说明：

## Software:
```
基于 xiaozhi-esp32 (https://github.com/78/xiaozhi-esp32)，固定 release v2.3.0（提交 1b48ebd7863695bf80d384c6c09af6299a6d7d0e，兼容 ESP-IDF 5.x）；服务端基于 xiaozhi-esp32-server (https://github.com/xinnan-tech/xiaozhi-esp32-server)，基线提交 27399a2fb64b5910196f438a256ce0a9f868481f。
ESP32-S3 负责离线唤醒、语音采集与播放、屏幕交互和 Agent 流程；大模型与语音合成均由服务端执行。
LLM 与语音服务都在本项目自建的 xiaozhi-esp32-server 中配置，测试阶段该服务部署在本机：ASR 与 TTS 由该服务执行，LLM 可调用云端 API（访问方式由项目负责人提供）或调试用 RTX 4090 服务。设备端不运行大模型或 TTS 模型。
```

## Hardware:
芯片规格已定为 ESP32-S3R8（8 MB PSRAM），**不是完整开发板型号**，R8 不代表 Flash 容量。选型仍需逐项确认屏幕、麦克风、扬声器、音频 codec、供电、Flash 容量、GPIO 与分区；xiaozhi-esp32 默认使用 16 MB Flash 分区表。4/8 MB Flash 的板卡不能仅凭芯片型号视作兼容。
```
参数分类	详细规格 
处理器 (CPU)	Xtensa® 32位 LX7 双核处理器，主频高达 240 MHz
内存 (SRAM)	512 KB 片上 SRAM，384 KB ROM 
闪存 (Flash)	通常板载 4 MB / 8 MB / 16 MB Flash 
外置内存 (PSRAM)	支持 Octal (8线) 或 Quad (4线) SPI PSRAM（常见 2MB / 8MB） 
无线连接	2.4 GHz Wi-Fi (802.11 b/g/n) + Bluetooth 5.0 (LE) 
AI 加速	额外增加向量指令集（Vector Instructions），加速神经网络计算 
USB 接口	支持外设 USB OTG、全速 USB 1.1、以及 USB Serial/JTAG 调试通道 
```

# 项目架构

首版沿用 xiaozhi-esp32 自带的小智 WebSocket/Opus（或 MQTT/UDP）协议，语音服务改为本项目自建的 xiaozhi-esp32-server。设备本地运行 ESP-SR 唤醒词检测；服务端完成 ASR、Agent/LLM 与 TTS 并回传音频，设备负责解码播放。**第一版不在 RTX 4090 上部署 ASR/TTS**；RTX 4090 目前只用于 LLM 调试。完整边界见 [架构概览](architecture/overview.md) 和 [服务部署说明](../deploy/README.md)。

# 项目说明

依赖源码、toolchain 缓存和生成物的项目内位置及命令见 [主机开发说明](deployment/local-development.md)。快速测试：

```sh
git submodule update --init --recursive
./bootstrap-idf.sh
. ./idf-env.sh
./test-host.sh
./build-xiaozhi-baseline.sh
```

构建命令使用 xiaozhi-esp32 v2.3.0 的默认板型（`bread-compact-wifi`）与 16 MB Flash 分区表，只是软件基线，不是实际 S3R8 整板的可烧录镜像。需确认完整开发板和外设后再配置目标板。该版本要求 ESP-IDF ≥ 5.5.2，项目固定的 esp-idf v5.5.5 满足要求；v2.4.0 起上游主线改到 ESP-IDF 6.x，本项目暂不跟进。

服务端（自建 xiaozhi-esp32-server）用 Docker 启动，与固件构建互不依赖：

```sh
cp deploy/server/.env.example deploy/server/.env   # 填密钥
./start-server.sh up
```

端口沿用上游默认（8000 设备 WebSocket、8003 服务端 HTTP、8002 智控台）；细节见 [服务部署边界](../deploy/README.md#server-deployment-docker)。

现有 LLM 主机探针用法和当前 vLLM 服务安全边界见 [服务部署说明](../deploy/README.md)。Lisa Beck 人格配置位于 `../config/Lisa.Beck/SOUL.md`，将作为 xiaozhi-esp32-server 侧智能体的人格来源，尚未接入服务端；正式接入需另行验证服务端提示词与设备侧设置的优先级。项目配置和任务对象隔离约定见 [config 说明](../config/README.md)。角色资料位于 [datasets/Lisa.Beck/](../datasets/Lisa.Beck/README.md)。

