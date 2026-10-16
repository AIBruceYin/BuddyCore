#!/usr/bin/env python3
"""BuddyCore 设备激活码生成器。

激活码组成：32 + 分类(2 位) + 日期(8 位 YYYYMMDD) + 随机(4 位)，共 16 位纯数字。
示例：32 | 01 | 20261016 | 0042  ->  3201202610160042
设备侧在配网界面（高级选项）填写激活码，服务端用它做白名单准入。

用法：
  python3 tools/gen_activation_code.py --category 01 --count 10
  python3 tools/gen_activation_code.py --category 01 --count 10 --append deploy/server/data/activation_codes.txt

分类位与位宽如需调整，改下面的常量并与 docs/plan.md 的记录保持一致。
"""

import argparse
import datetime
import pathlib
import secrets
import sys

PREFIX = "32"          # 32 = ESP32 平台
CATEGORY_DIGITS = 2    # 分类：01 试产 / 02 内测 / 03 正式 …
DATE_DIGITS = 8        # YYYYMMDD
RANDOM_DIGITS = 4      # 随机序号
TOTAL_DIGITS = len(PREFIX) + CATEGORY_DIGITS + DATE_DIGITS + RANDOM_DIGITS


def make_code(category: str, date: str, rnd: int) -> str:
    if len(category) != CATEGORY_DIGITS or not category.isdigit():
        raise ValueError(f"分类需为 {CATEGORY_DIGITS} 位数字，当前 {category!r}")
    if len(date) != DATE_DIGITS or not date.isdigit():
        raise ValueError(f"日期需为 {DATE_DIGITS} 位数字（YYYYMMDD），当前 {date!r}")
    code = f"{PREFIX}{category}{date}{rnd:0{RANDOM_DIGITS}d}"
    if len(code) != TOTAL_DIGITS or not code.isdigit():
        raise ValueError(f"生成的激活码非法：{code}")
    return code


def main() -> int:
    ap = argparse.ArgumentParser(description="生成 BuddyCore 设备激活码")
    ap.add_argument("--category", default="01", help="分类位（默认 01）")
    ap.add_argument("--count", type=int, default=1, help="生成数量")
    ap.add_argument("--date", default=None, help="日期 YYYYMMDD（默认今天）")
    ap.add_argument("--start", type=int, default=None, help="随机序号起点（默认随机）")
    ap.add_argument("--append", default=None, help="把生成的激活码追加写入该白名单文件")
    args = ap.parse_args()

    date = args.date or datetime.date.today().strftime("%Y%m%d")
    base = args.start if args.start is not None else secrets.randbelow(10 ** RANDOM_DIGITS)

    codes = [
        make_code(args.category, date, (base + i) % (10 ** RANDOM_DIGITS))
        for i in range(args.count)
    ]

    for code in codes:
        print(code)

    if args.append:
        path = pathlib.Path(args.append)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as f:
            for code in codes:
                f.write(code + "\n")
        print(f"已追加 {len(codes)} 条到 {path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
