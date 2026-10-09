# ESP32-S3 部署说明

## 当前状态

当前主机无可连接的 ESP32-S3。已验证的固件只是 XiaoClaw 软件基线：默认 `BREAD_COMPACT_WIFI` 板型、32 MB Flash 分区。ESP32-S3R8 只确认芯片及 8 MB PSRAM，不代表板载 Flash 容量或音频/屏幕引脚已确定。

**不得将当前基线镜像直接烧录到实际板卡。** 烧录前必须确认下列信息并生成匹配板卡的配置：

- 完整板卡/模组型号、Flash 容量和模式、PSRAM 类型/容量
- 麦克风、扬声器、音频 codec/功放及 I2S/I2C GPIO
- 屏幕型号、分辨率、接口及 GPIO
- XiaoClaw 支持的 board type；若无匹配板型，需先新增独立 board 配置
- 分区表适配实际 Flash，镜像不超出物理容量

## 首次部署步骤

### 1. 准备开发环境

在 BuddyCore 根目录执行：

```sh
./bootstrap-idf.sh
. ./idf-env.sh
```

工具和 ESP-IDF 源码固定版本见 [依赖说明](../dependencies/README.md)。

### 2. 确认板卡配置

根据实际硬件选择或新增 XiaoClaw board type，检查 `config.h`、`config.json`、Kconfig 和 partition table。移除上游默认 OTA URL/服务地址，改为经确认的开发语音服务器配置。不要把 Wi-Fi 密码、API key、token 或生产凭据提交到 Git；使用设备初始化流程、未跟踪的本地配置或受控密钥管理方式注入。

首版沿用 XiaoClaw 现有小智 WebSocket/Opus 语音实现和已配置语音服务器，ASR/TTS 运行在服务器；LLM 是单独的 HTTP API。部署前确认语音 OTA 返回的 WebSocket 地址、测试账号、网络可达性、TLS 证书和 LLM 地址。设备连接 RTX 4090 上的 LLM 时，必须使用设备可路由到的受控地址；不可把当前无鉴权的 `0.0.0.0:8002` 服务直接暴露到局域网或公网。

### 3. 构建并审查产物

```sh
./build-xiaoclaw-baseline.sh
```

该脚本当前构建的是默认软件基线，不是任何尚未确认板型的发布镜像。目标板配置完成后，使用对应 board 的 IDF defaults 和独立 build/sdkconfig 路径重新构建，再审查：

- 构建日志识别到的目标芯片与板型
- 实际 flash size、flash mode 和 partition table
- 应用、bootloader、assets、SR models、FATFS 分区大小及总占用
- OTA/WebSocket 语音服务器和 LLM endpoint 是否指向预期测试环境
- 日志中没有明文密钥或个人信息

产物位于 BuddyCore 忽略的 `build/`。检查构建报告及分区布局后再继续。

### 4. 首次烧录

确认已连接目标板且串口端口正确后，使用 IDF monitor 辨认设备：

```sh
idf.py -p <PORT> monitor
```

退出 monitor 后，对**已验证的目标板配置**运行烧录和监视。先阅读实际构建目录中 `flash_args` 以确认地址、分区和镜像，再执行：

```sh
idf.py -C <XIAOCLAW_SOURCE_DIR> -B <BOARD_BUILD_DIR> -p <PORT> flash monitor
```

示例中的 `<PORT>`、`<XIAOCLAW_SOURCE_DIR>` 和 `<BOARD_BUILD_DIR>` 必须替换为本机实际值。不要对当前默认 32 MB 基线使用本节命令烧录。首次写入/擦除前确认分区与板载 Flash 容量匹配；有需保留的数据时，不要执行 `erase-flash`。

### 5. 设备验收

首次启动检查串口日志、Wi-Fi 与 OTA 配置，再逐项验证：

1. ESP-SR 本地唤醒词检测。
2. 麦克风 Opus 音频上行及语音服务器返回 STT 文本。
3. mimi Agent 到 LLM API 的请求和回复。
4. `tts_request`、语音服务器返回音频及扬声器播放。
5. 屏幕状态、按键/打断、断网恢复和连续对话。
6. 长时间运行、内存、温度、供电与音频回授。

记录固件提交、板型、Flash/PSRAM、partition table、服务端点（不含密钥）、串口日志摘要、测试结果和缺陷。没有可用语音服务器凭据时，语音端到端项目标记为待验证，不以本地 LLM 文本探针代替。

### 6. 回滚

保留上一个已验证版本的镜像和对应 `flash_args`/board 配置。只有确认目标板分区布局兼容后才使用 OTA 回滚或重新烧录；不要把不同板型或 Flash 布局的镜像互刷。
