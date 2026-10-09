# 方案说明：

## Software:
```
基于 XiaoClaw (https://github.com/beancookie/xiaoclaw)，基线提交 55550bd461a5f760c256f59f32cbe2200a87e2c9。
ESP32-S3 负责离线唤醒、语音采集与播放、屏幕交互和 Agent 流程；大模型与语音合成均由服务端执行。
LLM 与语音服务分开配置。首版沿用 XiaoClaw 当前配置的小智语音服务器处理 ASR/TTS；LLM 可调用云端 API 或调试用 RTX 4090 服务。设备端不运行大模型或 TTS 模型。
```

## Hardware:
芯片规格已定为 ESP32-S3R8（8 MB PSRAM），**不是完整开发板型号**，R8 不代表 Flash 容量。选型仍需逐项确认屏幕、麦克风、扬声器、音频 codec、供电、Flash 容量、GPIO 与分区；XiaoClaw 上游建议 32 MB Flash（至少 16 MB）。4/8 MB Flash 的板卡不能仅凭芯片型号视作兼容。
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

首版沿用 XiaoClaw 当前的小智 WebSocket/Opus 协议及 OTA 配置的语音服务器。设备本地运行 ESP-SR 唤醒词检测；语音服务器返回 STT 文本并处理 `tts_request`，设备播放服务器回传的音频。**第一版不开发可替换语音网关，不在 RTX 4090 上部署 ASR/TTS**；RTX 4090 目前只用于 LLM 调试。完整边界见 [架构概览](architecture/overview.md) 和 [服务部署说明](../deploy/README.md)。

# 项目说明

依赖源码、toolchain 缓存和生成物的项目内位置及命令见 [主机开发说明](deployment/local-development.md)。快速测试：

```sh
git submodule update --init --recursive
./bootstrap-idf.sh
. ./idf-env.sh
./test-host.sh
./build-xiaoclaw-baseline.sh
```

构建命令使用上游默认板型与 32 MB Flash 假设，只是软件基线，不是实际 S3R8 整板的可烧录镜像。需确认完整开发板和外设后再配置目标板。

现有 LLM 主机探针用法和当前 vLLM 服务安全边界见 [服务部署说明](../deploy/README.md)。Lisa Beck 人格配置位于 `../config/Lisa.Beck/SOUL.md`，尚未写入固件；XiaoClaw 还内置自身身份提示，正式接入需另行验证优先级。项目配置和任务对象隔离约定见 [config 说明](../config/README.md)。角色资料位于 [datasets/Lisa.Beck/](../datasets/Lisa.Beck/README.md)。

