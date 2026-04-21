#!/usr/bin/env bash
# 全仓 GDScript 格式化（写入）。M1.1 起强制：commit 前若 fmt_check.sh 失败，先跑此脚本。
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v gdformat >/dev/null 2>&1; then
	echo "[fmt] gdformat 未安装；执行 'pip install \"gdtoolkit==4.*\"'。" >&2
	exit 127
fi

gdformat Runtime cli tests
