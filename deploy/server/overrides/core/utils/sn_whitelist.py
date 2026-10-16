"""BuddyCore 设备 SN 白名单（由 deploy/server/docker-compose.yml 挂载进容器）。

设备 SN 形如 32 + 分类 + 日期 + 随机数（16 位纯数字，具体位宽见 tools/gen-sn.py）。
白名单文件一行一个 SN，`#` 开头为注释；文件按 mtime 缓存，改完即时生效。
未启用（sn_whitelist.enabled 非 true）时一律放行，方便灰度上线。
"""

import os
import time
from typing import Tuple

_SN_LENGTH = 16
_cache = {"path": None, "mtime": 0.0, "sns": frozenset()}


def _read(path: str) -> frozenset:
    sns = set()
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                if line:
                    sns.add(line)
    except OSError:
        pass
    return frozenset(sns)


def load_whitelist(path: str) -> frozenset:
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        mtime = 0.0
    if _cache["path"] != path or _cache["mtime"] != mtime:
        _cache.update(path=path, mtime=mtime, sns=_read(path))
    return _cache["sns"]


def _resolve(path: str) -> str:
    if os.path.isabs(path):
        return path
    # 容器内工作目录即服务根目录（/opt/xiaozhi-esp32-server）
    return os.path.join(os.getcwd(), path)


def check_sn_allowed(config: dict, sn: str) -> Tuple[bool, str]:
    """返回 (是否允许, 原因)。config 为服务端整体配置。"""
    cfg = (config or {}).get("sn_whitelist") or {}
    if not cfg.get("enabled", False):
        return True, "whitelist disabled"

    sn = (sn or "").strip()
    if not sn:
        return False, "设备未上报 SN"
    if len(sn) != _SN_LENGTH or not sn.isdigit():
        return False, f"SN 格式非法（需 {_SN_LENGTH} 位数字）: {sn}"

    path = _resolve(cfg.get("file", "data/sn_whitelist.txt"))
    sns = load_whitelist(path)
    if sn in sns:
        return True, "ok"
    return False, f"SN {sn} 不在白名单（白名单共 {len(sns)} 条）"
