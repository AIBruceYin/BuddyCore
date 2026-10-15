# 园丁语音陪伴终端实施计划

更新日期：2026-10-14
项目目录：[BuddyCore](../README.md)
状态：ESP32-S3R8 芯片规格已定；分支 xiaozhiAI 已把依赖基线从 XiaoClaw 切换为 xiaozhi-esp32（固定 v2.3.0，兼容 ESP-IDF 5.x）与 xiaozhi-esp32-server，ESP-IDF v5.5.5、工具缓存、初始化/构建脚本仍在 BuddyCore。xiaozhi-esp32-server 测试期部署在本机；完整开发板外设与 Flash 仍待确认。

## 目标与边界

基于 [xiaozhi-esp32](https://github.com/78/xiaozhi-esp32) 与 [xiaozhi-esp32-server](https://github.com/xinnan-tech/xiaozhi-esp32-server)，在 ESP32-S3 上制作以园丁（艾玛·伍兹／丽莎·贝克）为主题的语音陪伴终端。首版提供中文人设对话、麦克风与扬声器交互、简单屏幕状态表情和合规通用 TTS。不实现实体动作、游戏玩法，也不直接复制游戏原画、台词或声音。

- **设备端：**离线唤醒、音频采集与播放、屏幕状态、网络连接、xiaozhi-esp32 的协议/代理流程及必要的本地会话数据。ESP32-S3 **不运行大模型或语音合成模型**。
- **生产服务：**自建的 xiaozhi-esp32-server 提供 ASR、Agent/LLM 与 TTS。离线唤醒不意味着离线对话。
- **调试服务：**首版先用自建的 xiaozhi-esp32-server，LLM 后端可指向当前 vLLM。RTX 4090 主机用于 LLM 调试；之后如需本地 ASR/TTS 引擎，再单独评估服务端替换，不阻塞首版。
- **现阶段验收上限：**本机不能连接 ESP32；只能完成服务协议测试、对话与状态模拟、素材预览和有工具链时的交叉编译。烧录、收音、播放、屏幕效果与稳定性必须留待实机。

## 架构与接口

```text
ESP32-S3 / xiaozhi-esp32
  |-- 本地唤醒、录音、Opus 音频、播放、屏幕表情
  |-- xiaozhi-esp32 小智语音协议 -- WebSocket 或 MQTT/UDP --> xiaozhi-esp32-server
  `-- 服务端 Agent -- HTTP --> OpenAI 兼容 LLM (/v1/chat/completions)

调试：服务端 LLM 可指向 RTX 4090；ASR/TTS 由 xiaozhi-esp32-server 提供
生产：LLM 与 ASR/TTS 都在自建的 xiaozhi-esp32-server 中配置
```

首版沿用 xiaozhi-esp32 自带的小智语音 WebSocket/Opus（或 MQTT/UDP）实现，服务端改为自建的 xiaozhi-esp32-server。设备上传音频、接收服务端识别文本；服务端 Agent 回复后合成 TTS 音频回传，设备解码播放。ASR、Agent/LLM 与 TTS 引擎都位于服务端，不在 ESP32 上。RTX 4090 先只作为服务端的 LLM 调试端点。若后续要把 ASR/TTS 换成本地引擎，属于可选工作，届时再验证服务端协议、TLS 与设备地址切换。

## 阶段与验收

状态约定：`待办`、`进行中`、`待硬件`、`完成`、`受阻`；完成时在对应项后记录日期和验收证据。

| 阶段 | 状态 | 工作与交付物 | 完成条件 |
| --- | --- | --- | --- |
| 0. 基线与选型 | 进行中 | 已确定 ESP32-S3R8（8 MB PSRAM）；xiaozhi-esp32、xiaozhi-esp32-server 与 ESP-IDF v5.5.5 均以子模块放在 BuddyCore `dependencies/`，ESP-IDF 工具缓存在忽略目录 `dependencies/.espressif/`；初始化/环境/构建脚本在 BuddyCore 根目录（此前 XiaoClaw 基线的重建记录见下方验收表）。 | 整板型号与接口明确后，选择或新增匹配的 xiaozhi-esp32 board/变体与分区并再次构建；此前的 XiaoClaw 32 MB 默认板型重建记录不能替代该项。 |
| 1. 角色人格 | 进行中 | 校对 [Lisa Beck 角色资料](../datasets/Lisa.Beck/README.md)；编写中文人设、说话风格与对话边界，整理 10 至 20 条测试场景；将 `../config/Lisa.Beck/SOUL.md` 配置到 `/fatfs/config/SOUL.md`，检查默认文件初始化不会覆盖已有用户数据。 | 用主机侧样例验证语气、身份、敏感经历处理及失败回退；不把未经核实的角色设定当作事实。 |
| 2. 服务接入 | 进行中 | LLM：已验证 RTX 4090 上现有 vLLM `qwen3.5-2b:8002` 的文本及园丁人格单轮请求；工具调用返回 400，暂不改共享服务。语音：首版改为自建 xiaozhi-esp32-server（ASR、Agent/LLM、TTS），协议沿用 xiaozhi-esp32 的小智 WebSocket/Opus 或 MQTT/UDP；不部署 RTX 4090 ASR/TTS。检查服务端部署地址、账号配置和连接要求，但不擅自更改生产端点。 | 有可用的自建 xiaozhi-esp32-server 实例及可访问网络后，验证设备握手、识别文本与 TTS 回包；LLM 继续验证文本与工具调用。明确密钥管理和录音保留策略。 |
| 3. 屏幕表情 | 待办 | 为待机、聆听、思考、说话和错误状态设计原创静态表情；检查目标板显示实现及 `SetEmotion` 调用链。当前上游部分显示动画逻辑被注释，必要时做最小适配。 | 主机预览小屏素材；状态映射测试通过。实机显示仍待阶段 5 验收。 |
| 4. 主机集成 | 待办 | 测试角色文本、LLM 探针、状态映射及错误处理；语音接口首版不另造 mock 网关，基于上游消息契约准备测试说明和配置检查。整理配置模板与固件构建步骤。 | mock/LLM 测试留存结果；固定提交及补丁可在 ESP-IDF 下交叉编译。编译通过不代表 ASR/TTS 实际服务或设备已跑通。 |
| 5. 实机联调 | 待硬件 | 板卡到位后烧录，连接自建的 xiaozhi-esp32-server，检查唤醒、ASR、LLM、TTS、显示、打断、断网恢复、音频啸叫、资源使用及长时间运行。 | 串口日志和逐项测试记录齐全；若板型不受上游支持，再按 xiaozhi-esp32 上游指南新增独立板型及 OTA 标识。 |
| 6. 特定声线 | 受阻：待授权 | 用户希望复刻游戏中特定声线。取得样本的训练、播放和相应展示／分发许可后，选择支持该用途的 TTS 与网关适配方案。 | 有许可记录后完成主机试听、延迟与成本测试，再做实机流式播放测试；此前持续使用通用合规 TTS，不从试听视频提取训练样本。 |

阶段 1、2、3 可在阶段 0 确定源码基线后并行；阶段 4 集成三者；阶段 5 依赖硬件和当前语音服务访问条件。首版不开发语音网关；声线阶段不阻塞首版。

## 当前决策与待确认项

- 已决定：ESP32-S3 不做 LLM／TTS 模型推理；生产用云端服务，开发时可用 RTX 4090 模拟同样的设备侧接口。
- 已决定：首版包含语音陪伴和简单屏幕表情，不包含机械动作；特定游戏声线目标保留，但当前无授权。
- 已决定：芯片规格 ESP32-S3R8，带 8 MB PSRAM；R8 不表示 Flash 容量，也不指定屏幕、音频器件或 GPIO。
- 已决定（2026-10-14 分支切换后取代）：第一版曾沿用 XiaoClaw 的本地唤醒、WebSocket/Opus、服务器 ASR/STT 回包与 TTS 播放实现；现改为 xiaozhi-esp32 固件 + 自建 xiaozhi-esp32-server。仍不迁移 ASR/TTS 到 RTX 4090。
- 已决定：RTX 4090 首版只用于 LLM 主机调试。将 ASR/TTS 接到 RTX 4090 是后续可选项，必须先单独设计/验证小智兼容服务，不作为首版前置。
- 已决定：依赖源码固定在 BuddyCore `dependencies/` 下的子模块中；工具缓存和编译输出也落在 BuddyCore 下但不提交。初始化、环境、测试和构建脚本直接位于 BuddyCore 根目录。
- 已决定（分支 xiaozhiAI，2026-10-14）：固件基线由 XiaoClaw 改为 xiaozhi-esp32，服务端改为自建的 xiaozhi-esp32-server；`dependencies/xiaoclaw` 子模块在该分支移除，`dependencies/patches/xiaoclaw/` 仅留作历史参考。
- 已决定（2026-10-14）：保留 esp-idf v5.5.5，把 xiaozhi-esp32 固定到 v2.3.0（提交 `1b48ebd7863695bf80d384c6c09af6299a6d7d0e`）；v2.4.0 起上游主线要求 ESP-IDF 6.x，该升级留待后续单独决策。
- 待确认：xiaozhi-esp32 的目标 board/变体（沿用上游板型或新增 BuddyCore 板型）以及 16 MB Flash 分区表是否匹配实际硬件。
- 已决定（2026-10-14）：xiaozhi-esp32-server 的测试阶段部署在项目负责人本机；其调用的云端大模型访问方式（地址、账号、密钥）同样由项目负责人提供，不入库。
- 已决定（2026-10-14）：服务端用 Docker 部署，根目录 `start-server.sh` 统一本地与云端流程，端口保持上游默认 8000/8002/8003；生产阶段沿用同一 compose 与脚本，只需替换 `.env`、`PUBLIC_HOST` 与镜像标签。
- 已确认（2026-10-15）：火山方舟 LLM 已打通——`doubao-seed-2-0-lite-260428` 单轮对话与工具调用（`finish_reason=tool_calls`）均正常；上游配置默认的 `doubao-seed-2-0-lite-260215` 在本账号为 `Retiring` 状态会返回 404，已改钉 260428。
- 已确认（2026-10-15）：豆包 TTS 打通——新版单一 API Key（`X-Api-Key`）+ 资源 `seed-tts-2.0` + `*_uranus_bigtts` 音色实测返回音频；旧资源 `volc.service_type.10029`（湾湾小何）配该 Key 会 403，资源与音色必须配对。
- 待确认：豆包 ASR 的新版鉴权（本版本服务端 ASR 仍用旧版 appid/access_token，暂以本地 FunASR 兜底）；如需新版 Key 走 ASR，需要按同一思路补丁化。
- 已决定：按任务对象隔离资料与人格配置：`datasets/<ObjectName>/` 保存对象资料，`config/<ObjectName>/` 保存对象运行配置；Lisa Beck 已迁入各自子目录。项目级实施计划与构建默认项留在 `config/` 根层。
- 待确认：整板／模组具体型号及 Flash 容量、屏幕与音频器件和引脚。
- 待确认：自建 xiaozhi-esp32-server 的部署地址、网络可达性、TLS/证书要求和测试账号；服务端部署完成前，设备侧语音链路无法实测。
- 本机 vLLM 服务当前以 `0.0.0.0:8002` 对外监听、未配置 API 鉴权；仅用主机回环测试，设备接入前必须先限制网络访问并加鉴权，不改变其他项目的现有服务配置。
- 待确认：角色资料与素材来源、授权范围；视频试听链接仅作为参考，不是训练素材。

## 验收记录

| 日期 | 阶段 | 结果／证据 | 未解决问题 |
| --- | --- | --- | --- |
| 2026-09-30 | 计划 | 确定架构、阶段与无硬件验证边界 | 板卡、服务与声线许可待定 |
| 2026-09-30 | 基线／主机原型 | 上游 HEAD 固定为 `55550bd461a5f760c256f59f32cbe2200a87e2c9`；人格配置现归档为 [Lisa Beck SOUL.md](../config/Lisa.Beck/SOUL.md)；初始主机协议测试 4 项通过（现归档在 `../services/check-llm.test.mjs`）。主机检测到 RTX 4090（24 GB）。 | 板卡未定；人格尚未写入固件；当时尚未部署或实测语音服务及设备。 |
| 2026-09-30 | 选型更新 | 用户选定 ESP32-S3R8；Flash 和外设信息尚未提供。ESP-IDF 安装开始准备。 | 待确认完整板卡 BOM、GPIO 和可用分区；暂不能选择 XiaoClaw 板型。 |
| 2026-09-30 | 工具链自检 | 早期在独立 ESP-IDF 安装下完成官方 ESP32-S3 hello_world 编译；其默认 2 MB Flash 配置仅用于工具链自检。之后 ESP-IDF 工具缓存已移入 BuddyCore 并用于项目内构建。 | hello_world 结果不代表实际 S3R8 板卡 Flash、外设或板级配置。 |
| 2026-09-30 | 本地 LLM 文本回环 | 现有 vLLM `GET /v1/models` 返回 `qwen3.5-2b`；[主机探针](../services/check-llm.mjs)以 `LLM_PROBE_TOOLS=0 LLM_SOUL_FILE=config/Lisa.Beck/SOUL.md` 向 8002 发送请求，获得中文园丁自我介绍；`node --test ../services/check-llm.test.mjs` 5 项通过。 | 默认带 `tool_choice: auto` 的请求返回 400：服务未启用工具解析器。语音服务器尚未实机验证，单轮回复不代表完整设备对话。 |
| 2026-09-30 | XiaoClaw 软件基线 | 固定提交 `55550bd461a5f760c256f59f32cbe2200a87e2c9` 作为项目内子模块；[主机配置](../config/firmware/sdkconfig.host.defaults)和 [XiaoClaw 补丁](../dependencies/patches/xiaoclaw/0001-fix-lamp-controller-conflict.patch)经根目录 `build-xiaoclaw-baseline.sh` 在隔离 worktree 中应用并交叉编译成功，镜像为 `0x2feef0` 字节（app 分区 `0x500000`）。 | 默认板型为 `BREAD_COMPACT_WIFI`、分区假定 32 MB Flash 且含上游 OTA 地址；不能烧录到未知 S3R8 整板，未完成角色固件集成。 |
| 2026-09-30 | 首版语音方案确定 | 第一版复用 XiaoClaw 当前语音实现：本地 ESP-SR 唤醒、WebSocket/Opus 上传、语音服务器 ASR/TTS；不新增网关或 RTX 4090 语音模型部署。 | 当前 OTA 语音服务器配置/凭据尚未核验，无法在无设备条件下确认其实际 ASR/TTS 账户或做端到端实测。 |
| 2026-09-30 | 项目结构与本地依赖 | XiaoClaw、ESP-IDF v5.5.5 及 IDF 递归子模块位于 BuddyCore `dependencies/`；工具缓存位于忽略目录 `dependencies/.espressif/`；初始化、主机测试和隔离 worktree 构建脚本均通过验证。 | 完整开发板 Flash/外设配置、当前语音服务器访问条件待确认。 |
| 2026-09-30 | 干净重建与部署说明 | 删除原 `build/` 并执行 `./build-xiaoclaw-baseline.sh`，从头编译成功；`xiaozhi.bin` 为 `0x2feef0` 字节，app 分区余量约 40%；`./test-host.sh` 5 项通过。新增 [ESP32-S3 部署说明](../deploy/esp32-s3.md)，列出硬件确认、构建审查、烧录和验收流程。 | 未连接设备；整板 Flash/外设未知，未烧录；当前镜像仍不可作为实际 S3R8 板卡发布镜像。 |

| 2026-10-14 | 分支切换（xiaozhiAI） | 新建分支 `xiaozhiAI`；依赖基线改为 xiaozhi-esp32 `e076ac496e2d93dc3a2308a0491d745afe9489ab` 与 xiaozhi-esp32-server `27399a2fb64b5910196f438a256ce0a9f868481f`（均为上游 `main`）；移除 `dependencies/xiaoclaw` 子模块，保留 `dependencies/patches/xiaoclaw/` 作历史参考；根目录构建入口改为 [`build-xiaozhi-baseline.sh`](../build-xiaozhi-baseline.sh)。 | xiaozhi-esp32 要求 ESP-IDF ≥ 6.0.1，当前 esp-idf 固定 v5.5.5，固件基线尚未交叉编译通过；xiaozhi-esp32-server 尚未部署；目标 board 未定。 |
| 2026-10-14 | 版本决策与测试部署 | 确定保留 ESP-IDF v5.5.5，把 xiaozhi-esp32 改为固定 release `v2.3.0`（提交 `1b48ebd7863695bf80d384c6c09af6299a6d7d0e`，声明 `idf: >=5.5.2`）；构建入口改为按 Kconfig 板型直接调用 `idf.py`（该版本尚无 `scripts/build.py`）。测试阶段 xiaozhi-esp32-server 部署在项目负责人本机，云端 LLM 访问方式由项目负责人提供。 | 本机无 ESP-IDF 工具链（`dependencies/.espressif` 为空、无 cmake/ninja），基线尚未在新的固定版本下交叉编译；目标 board 未定；服务端与本机 LLM 访问细节尚未记录。 |
| 2026-10-14 | 服务端 Docker 部署 | 新增 [docker-compose.yml](../deploy/server/docker-compose.yml)（上游 `docker-compose_all.yml` 参数化：端口沿用 8000/8003/8002，智控台容器放入 `console` profile）、[.env.example](../deploy/server/.env.example)、[config/server/](../config/server/) 两个配置模板与根目录 [`start-server.sh`](../start-server.sh)（`up/config/status/logs/pull/restart/down`）；轻量模式生成的 `data/.config.yaml` 已验证可包含火山方舟 `DoubaoLLM`（`base_url` + `doubao-seed-2-0-lite-260215`）与 Lisa Beck 人格提示词，compose 两种模式均通过 `docker compose config`，未提交任何密钥。 | 火山方舟密钥可鉴权、`/models` 可列出该模型，但 `chat/completions` 对所有模型返回 404 `InvalidEndpointOrModel.NotFound`，需开通或改 `ep-` 接入点；豆包语音缺 appid/access_token；本机 Docker 引擎未启动，容器尚未实跑；`data/.config.yaml` 的 YAML 结构仅做人工核对。 |
| 2026-10-15 | LLM 打通与模型 id 修正 | 实测火山方舟：`doubao-seed-2-0-lite-260428` 对话正常并返回 `tool_calls`（`get_datetime`）；确认 `GET /api/v3/models` 的 `status` 字段（Shutdown 83 / Retiring 17 / 可用 35）决定可否调用，上游默认的 260215 属 Retiring 故 404；`.env`（本地）与 [.env.example](../deploy/server/.env.example) 已改用 260428，`./start-server.sh config` 重建 `data/.config.yaml` 成功。 | 豆包语音 appid/access_token 仍未提供，暂用 FunASR + EdgeTTS；本机 Docker 引擎未启动，容器与设备链路尚未实跑。 |
| 2026-10-15 | 豆包 TTS 打通（补丁化） | 依据官方双向流式 TTS 文档，新增 [`patches/xiaozhi-esp32-server/0001-huoshan-tts-api-key-auth.patch`](../dependencies/patches/xiaozhi-esp32-server/0001-huoshan-tts-api-key-auth.patch)，让 provider 在配置 `api_key` 时改发 `X-Api-Key` + `X-Api-Resource-Id`；`start-server.sh` 把补丁物化到 `build/server-overrides/`，compose 只读挂载到容器内，子模块与上游镜像都不改动。实测（复用服务端自身协议实现 + 新版鉴权）：`seed-tts-2.0` + `zh_female_gaolengyujie_uranus_bigtts` 返回 190,984 字节 PCM；资源 `volc.service_type.10029` 用该 Key 连接被拒（HTTP 403）。 | 音色需换成 `*_uranus_bigtts` 系列（Lisa 目标声线需在控制台挑选）；ASR 仍为本地 FunASR；Docker 引擎未启动，容器链路尚未实跑。 |

实施时在此表追加记录，并同步更新上方阶段状态。已有主机侧交叉编译与测试结果；没有烧录或运行设备测试。
