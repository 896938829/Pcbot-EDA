#!/usr/bin/env bash
# 双轨测试入口：GUT 可用则走 GUT；否则回退轻量 runner。
# 退出码：任一测试失败非 0；Godot 找不到也非 0。
set -euo pipefail

cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"

if [[ ! -x "$(command -v "$GODOT")" ]]; then
	echo "[run_tests] '$GODOT' 不在 PATH；设置 GODOT 环境变量指向可执行文件。" >&2
	exit 127
fi

if [[ -f "addons/gut/plugin.cfg" ]]; then
	echo "[run_tests] 走 GUT 路径"
	"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd \
		-gdir=res://tests/gut/ -gexit
else
	echo "[run_tests] GUT 未安装，回退 lightweight_runner"
	"$GODOT" --headless -s tests/lightweight_runner.gd
fi
