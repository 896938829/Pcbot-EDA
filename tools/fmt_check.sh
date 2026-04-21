#!/usr/bin/env bash
# 全仓 GDScript 格式检查（不写入）。提交前必跑；CI 门禁同此脚本。
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v gdformat >/dev/null 2>&1; then
	echo "[fmt_check] gdformat 未安装；执行 'pip install \"gdtoolkit==4.*\"'。" >&2
	exit 127
fi

gdformat --check Runtime cli tests
