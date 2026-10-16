"""BuddyCore 设备激活码白名单（由 deploy/server/docker-compose.yml 挂载进容器）。

激活码形如「32 + 分类 + 日期 + 随机数」（16 位纯数字，位宽见 tools/gen_activation_code.py），
在配网界面写入设备 NVS，设备在 OTA 与 WebSocket 两次握手里都会带上。

白名单文件一行一个激活码，`#` 开头为注释；按文件 mtime 热加载，改完即生效。
`activation_whitelist.enabled` 不为 true 时一律放行，方便先上线门禁再逐个发码。
"""

import os
from typing import Iterable, Mapping, Optional, Tuple

ACTIVATION_CODE_LENGTH = 16
# 设备/网关可能用到的头部名与 JSON 字段名在这里统一收口，避免各处口径不一致
CODE_HEADER_NAMES = ("activation-code", "sn", "serial-number")
CODE_JSON_FIELDS = ("activation_code", "sn")

_cache = {"path": None, "mtime": 0.0, "codes": frozenset()}


def _read(path: str) -> frozenset:
    codes = set()
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                if line:
                    codes.add(line)
    except OSError:
        pass
    return frozenset(codes)


def load_whitelist(path: str) -> frozenset:
    """按 mtime 缓存读取白名单，文件没变就不重复读盘。"""
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        mtime = 0.0
    if _cache["path"] != path or _cache["mtime"] != mtime:
        _cache.update(path=path, mtime=mtime, codes=_read(path))
    return _cache["codes"]


def _resolve(path: str) -> str:
    if os.path.isabs(path):
        return path
    # 容器内工作目录即服务根目录（/opt/xiaozhi-esp32-server）
    return os.path.join(os.getcwd(), path)


def _get(mapping: Optional[Mapping], names: Iterable[str]) -> str:
    if not mapping:
        return ""
    for name in names:
        value = mapping.get(name)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def code_from_sources(
    headers: Optional[Mapping] = None, payload: Optional[Mapping] = None
) -> str:
    """取出设备上报的激活码：先看 JSON 请求体（OTA 用 POST 上报），再看请求头。"""
    code = _get(payload, CODE_JSON_FIELDS)
    if code:
        return code
    lowered = {str(k).lower(): v for k, v in (headers or {}).items()}
    return _get(lowered, CODE_HEADER_NAMES)


def check_activation_code_allowed(config: dict, code: str) -> Tuple[bool, str]:
    """返回 (是否允许, 原因)。config 为服务端整体配置。"""
    cfg = (config or {}).get("activation_whitelist") or {}
    if not cfg.get("enabled", False):
        return True, "whitelist disabled"

    code = (code or "").strip()
    if not code:
        return False, "设备未上报激活码"
    if len(code) != ACTIVATION_CODE_LENGTH or not code.isdigit():
        return False, f"激活码格式非法（需 {ACTIVATION_CODE_LENGTH} 位数字）: {code}"

    path = _resolve(cfg.get("file", "data/activation_codes.txt"))
    codes = load_whitelist(path)
    if code in codes:
        return True, "ok"
    return False, f"激活码 {code} 不在白名单（白名单共 {len(codes)} 条）"
