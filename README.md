# BuddyCore

基于 xiaozhi-esp32 与 ESP32-S3R8 的园丁语音陪伴原型（分支 `xiaozhiAI`）。固件沿用 xiaozhi-esp32；语音链路与大模型由自建的 xiaozhi-esp32-server 提供。

## 当前范围

- ESP32-S3 负责本地唤醒、音频采集/播放、显示和 Agent 固件流程，不运行 LLM 或 TTS 模型。
- ASR 与 TTS 由本项目自建的 xiaozhi-esp32-server 提供，不再沿用 XiaoClaw 时代的外部语音服务器配置。
- RTX 4090 用于本地 LLM 调试。S3R8 已确定，但完整开发板、Flash 容量和音频/屏幕器件尚待确认。
- 无设备阶段可做主机测试和 ESP-IDF 交叉编译；不能据此声称实机验证完成。

## 项目导航

- [实施计划](docs/plan.md)
- [全局配置与对象配置约定](config/README.md)
- [任务对象与资料索引](datasets/README.md)
- [Lisa Beck / 园丁资料](datasets/Lisa.Beck/README.md)
- [Lisa Beck 人格配置](config/Lisa.Beck/SOUL.md)
- [架构概览](docs/architecture/overview.md)
- [主机开发与构建](docs/deployment/local-development.md)
- [服务部署边界](deploy/README.md)
- [ESP32-S3 设备部署](deploy/esp32-s3.md)
- [依赖版本与更新方式](dependencies/README.md)

## 快速开始

首次克隆后，按以下顺序准备项目：

```sh
git submodule update --init --recursive
./bootstrap-idf.sh
. ./idf-env.sh
```

脚本职责与先后关系：

| 脚本 | 用途 | 运行时机 |
| --- | --- | --- |
| `./bootstrap-idf.sh` | 检查主机依赖、初始化子模块，并将 ESP32-S3 编译工具和 Python 环境安装到项目忽略目录；不会激活当前终端。 | 首次设置，或工具缺失/损坏时运行；可重复运行。 |
| `. ./idf-env.sh` | 把 ESP-IDF 环境载入当前 shell；必须 source。 | 每个新终端一次；手动运行 `idf.py` 时使用。 |
| `./build-xiaozhi-baseline.sh` | 自动载入 IDF 环境，按指定 board/变体交叉编译 xiaozhi-esp32。 | 每次需要构建软件基线时运行；不要求先手动 source 环境。 |
| `./test-host.sh` | 运行主机端协议与配置测试，不依赖 ESP-IDF。 | 开发期间随时运行。 |

常用验证命令：

```sh
./test-host.sh
./build-xiaozhi-baseline.sh
```

固件基线使用 xiaozhi-esp32 的 `bread-compact-wifi` 板型（16 MB Flash 分区表），仅用于主机编译验证。确认实际开发板后才能选择或新增正确板型与分区；不要将基线镜像烧录到未经确认的硬件。注意 xiaozhi-esp32 当前要求 ESP-IDF 6.0.1 及以上，而项目固定的 esp-idf 仍是 v5.5.5，构建前需先确定 IDF 版本。
