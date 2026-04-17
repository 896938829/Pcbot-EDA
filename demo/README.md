# Demo: LED 闪烁电路

M1 端到端示例：NE555 经典非稳态振荡器驱动 LED。

## 内容

- `led_blink.pcbproj` — 工程入口（Godot 打开后扫这里）
- `led_blink.sch.json` — 原理图：U1 (NE555) + R1/R2 (定时) + C1 (RC) + R3 (限流) + D1 (LED) + VCC1/GND1
- `library/symbols/*.sym.json` — 元件符号
- `library/components/*.comp.json` — 元件条目
- `.pcbot/diagnostics.jsonl` — CLI 自检产出的违例历史（入 git）

## 重新生成

```bash
godot --headless -s tests/build_demo.gd
```

该脚本会通过内部命令路由重建所有设计文件，输出是稳定 JSON（键字典序、LF、2 空格缩进）。

## 用 Godot 打开

直接双击 `led_blink.pcbproj`，或在 Godot 项目中：

```
editor → 打开工程 → 选 demo/led_blink.pcbproj
```

M1 的 GUI 为只读：编辑请走 CLI（见 [docs/skills/](../docs/skills/)）。
