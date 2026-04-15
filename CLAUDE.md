# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指引。

## 项目概述

Pcbot EDA — 以AI为设计主体的PCB设计工具，基于 Godot Engine 4.6 构建。AI代理通过CLI驱动完整设计流程（原理图 → 布局 → 布线 → 审查）；人类通过编辑器UI查看和审核。编辑器是被动的——只响应AI指令，不内置AI功能。

## 技术栈

- **引擎**：Godot 4.6，GL Compatibility 渲染器，Jolt Physics（3D）
- **语言**：GDScript（主语言），C++/C# 用于性能关键模块
- **AI接口**：CLI，通过 stdin/stdout/stderr 通信，JSON-RPC 2.0 消息格式
- **测试框架**：GUT（Godot Unit Test）
- **构建系统**：SCons（Godot 原生）
- **版本控制**：Git，行尾统一为 LF（`.gitattributes`）

## 项目结构

```
Assets/       # 美术资源、模型、贴图、导入资源
Runtime/      # 运行时脚本和逻辑
Scenes/       # Godot 场景文件（.tscn）
docs/         # 设计文档（需求整理、技术栈方案）
```

## 常用命令

```bash
# 在 Godot 编辑器中运行项目
# 用 Godot 4.6 打开 project.godot，按 F5 运行

# 运行 GUT 单元测试（需先创建测试场景）
godot --headless -s addons/gut/gut_cmdln.gd

# 导出（需先配置导出预设）
godot --headless --export-release "Windows Desktop" build/pcbot.exe
```

## 架构要点

- **AI设计、人类审核**：所有设计操作必须通过CLI可达，不能仅限GUI
- **中间文件**：AI操作记录为JSONL格式；设计状态快照使用JSON/YAML——必须对git diff友好
- **元件库**：SQLite本地数据库，符号用SVG，封装定义用JSON
- **DRC/ERC引擎**：计划用C++模块实现，使用R-tree/四叉树空间索引
- **坐标系**：Godot默认单位是米，项目需建立mm/µm精度映射
- **模块化插件架构**：功能按需加载，使用Godot插件系统和自定义事件总线

## 编码规范

- 所有文本文件使用 UTF-8 编码（`.editorconfig`）
- 行尾：仅 LF
- 设计文档使用中文
