# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指引。

## 项目定位

Pcbot EDA — 以 AI 为设计主体的 PCB EDA 工具，Godot 4.6 承载。**AI 通过 CLI 驱动设计（原理图 → 布局 → 布线 → 审查），编辑器被动渲染**。M1 聚焦：元件库 + 原理图数据模型 + CLI 骨架 + AI 中间文件，只读 GUI。详细里程碑范围见 [docs/plan/实现计划-M1.md](docs/plan/实现计划-M1.md)。

## 技术栈

- **引擎**：Godot 4.6（GL Compatibility 渲染，Jolt 3D 物理，Windows 下 d3d12 RenderingDevice）
- **语言**：GDScript（M1 唯一运行时语言；C++ GDExtension / C# 留 M2+）
- **AI 接口**：CLI headless，JSON-RPC 2.0 over stdin/argv，结果 stdout，日志 stderr
- **测试**：GUT（`addons/gut/`）+ 自写轻量 runner（`tests/lightweight_runner.gd`）
- **Autoload**：`EventBus`（`Runtime/core/event_bus.gd`）、`Logger`（`Runtime/core/logger.gd`）

## 仓库布局

```
Runtime/
  core/       # 基石：unit_system / error / result / event_bus / logger（无业务依赖）
  io/         # 纯 I/O：json_stable / yaml / jsonl / svg / project_fs / run_report / diagnostics_log
  modules/    # 领域模块：project, symbol, library, schematic, check, skills, run
              # 每个模块下 commands.gd 注册 CLI 方法，其它是领域数据/算法
  ui/         # 编辑器 UI（只读渲染为主）：main_window.gd, schematic_view.gd
cli/          # headless 入口：main.gd（SceneTree）+ jsonrpc.gd + command_registry.gd
Scenes/       # Godot 场景（Main.tscn）
tests/
  unit/       # 每个 *_test.gd 暴露 `static func run() -> Array[{name, ok, msg}]`
  integration/
  lightweight_runner.gd   # 不依赖 GUT 的 runner；CI/本地快速回归
  assert_util.gd, build_demo.gd
demo/         # led_blink 示例工程（M1 端到端验收目标）
docs/
  architecture/ # 架构设计 + ADR
  conventions/  # 代码规范 + 文档规范（务必遵守）
  plan/         # 里程碑实现计划
  skills/       # 每个 CLI 命令的 Skills YAML（AI 可读手册）
addons/gut/   # GUT 测试框架
```

## 运行与测试命令

```bash
# 双轨入口（首选）：装 GUT 走 GUT；否则回退 lightweight_runner。
tools/run_tests.sh

# 轻量 runner（最快回归，无 GUT 依赖）：
godot --headless -s tests/lightweight_runner.gd

# GUT 全量（需先 godot --headless --import 让 class_name 注册）：
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut/ -gexit

# 单个测试脚本（临时加到 lightweight_runner.gd TESTS 列表，或用 GUT 的 -gselect）：
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=tests/unit/<name>_test.gd -gexit

# CLI 调用（argv 模式）：
godot --headless -s cli/main.gd -- '{"jsonrpc":"2.0","id":1,"method":"project.new","params":{"path":"demo/led_blink.pcbproj"}}'

# CLI 调用（stdin 模式）：
echo '{"jsonrpc":"2.0","id":1,"method":"schematic.list_components","params":{}}' | godot --headless -s cli/main.gd

# 在编辑器里跑：打开 project.godot，F5
```

CLI 退出码走 `Runtime/core/error.gd::code_to_exit`；成功 0，用户错非 0。方法列表：`cli/main.gd::_register_all` 聚合 `ProjectCommands / SymbolCommands / LibraryCommands / SchematicCommands / CheckCommands / SkillsCommands / RunCommands`。

## 格式化

```bash
# 提交前检查（不写入）：
tools/fmt_check.sh

# 一键格式化（写入）：
tools/fmt.sh
```

依赖 `gdtoolkit` 4.x（`pip install "gdtoolkit==4.*"`）。M1.1 已落工具链，但**全仓 fmt baseline 未跑**——
gdformat 4.5 重排部分多行 `func():` lambda 后会撞 Godot 4.6 解析 bug，需先把测试代码里的多行 lambda 抽为
helper / 单行化（follow-up）。新写代码请尽量手动遵循 gdformat 默认风格，避免在表达式中写多行 lambda。
M2 起 CI 挂 `tools/fmt_check.sh` 门禁。

## 架构铁律

这些是设计不变量，违反视作 bug：

- **AI 与人类共用 CLI**：任何设计操作必须有 `Runtime/modules/<domain>/commands.gd` 注册的 CLI 方法；GUI 编辑动作经 CLI 命令落盘（不直接改 JSON、不绕过 `Result`）；GUI 与 CLI 地位对等。编辑器**不得**嵌入 AI 推理（无 LLM 调用、无本地模型）。详见 [ADR-0005](docs/architecture/ADR-0005-gui-as-first-class-edit-surface.md)。
- **模块边界**：`Runtime/modules/<domain>/` 只能依赖 `Runtime/core/` 与本模块内脚本。跨模块通信走 `EventBus` 或显式注入。**禁止**跨模块 `preload` 他人内部脚本。
- **I/O 分层**：`Runtime/io/` 不得引用领域模型；上层负责映射。
- **坐标单位**：内部一律 `int64` 纳米（nm）。常量 `NM_PER_MM=1_000_000`、`NM_PER_MIL=25_400`，换算集中在 `Runtime/core/unit_system.gd`。跨模块 API 不得暴露 `float` 坐标，UI/导出层才做浮点转换。
- **错误处理**：CLI 边界统一 `Result.ok(...)` / `Result.err(code, msg, data?)`，再由 `cli/jsonrpc.gd` 转 JSON-RPC。内部不抛异常穿越模块边界。错误码枚举集中在 `Runtime/core/error.gd`，新增需评审。
- **日志**：全部经 `Logger`；禁止散落 `print()`（CLI 的 stdout 是 JSON-RPC 响应通道，污染会破坏协议）。

## AI 中间文件（`.pcbot/`）白名单

**只允许**以下三个文件，新增任何文件须走 ADR：

| 文件 | 写法 | 入 git |
| --- | --- | --- |
| `.pcbot/last-run.json` | 每次 CLI 调用**覆盖写**；固定字段 `ts/command/params/exit_code/errors/warnings/touched_files`；键字典序 | 否 |
| `.pcbot/diagnostics.jsonl` | **追加写**，每行严格 JSON；按 `{rule_id, ref}` 去重；消除违例追加带 `resolved_by_commit` 的记录，不改旧行 | **是**（质量史） |
| `.pcbot/commit-msg` | 变更成功后覆盖写；纯文本；AI 可 `git commit -F .pcbot/commit-msg` | 否 |

**禁止**新增 `*.ops.jsonl` / `*.snap.yaml` / "设计状态投影" / "操作重放缓存" 等与源文件+git 重复的文件。

## 文件格式约定

- JSON 源文件（SSOT）：键字典序、2 空格缩进、UTF-8、末尾 LF、数值不保留无意义 `.0`——走 `Runtime/io/json_stable.gd`。
- SVG 符号：`viewBox` 必填，单位 mm，剔除编辑器私有属性，**不入 LFS**（保持 diff 可读）。
- 元件库 SQLite 索引：**不入 git**，从 JSON 源可重建。
- 顶层所有持久化格式带 `"format_version": <int>`；破坏性升级需提交 `Runtime/io/migrations/v<N>_to_v<N+1>.gd` 并在 commit 正文标注 `BREAKING`。

## 编码规范要点

完整规范见 [docs/conventions/代码规范.md](docs/conventions/代码规范.md)；高频项：

- 缩进 **Tab**，行尾 LF，行长 ≤100（硬限 120），文件末尾一个空行，全文 UTF-8。
- 命名：成员/函数/变量 `snake_case`；常量 `UPPER_SNAKE_CASE`；`class_name` 仅给可复用 `Resource`/服务类用（场景内脚本不用）；`_` 前缀表私有。
- 公共 API 与 `@export` 必须写类型注解；可失败函数返回 `Result`。
- CLI 命令处理函数签名固定：`func(params: Dictionary) -> Result`。
- 注释：不写"做了什么"；只写"为什么"（约束、绕过的 bug、性能取舍）。公共函数用中文 `##` docstring。

## Git 与提交

- 分支：`main` 保持绿；`feat/<短名>` / `fix/<短名>` / `docs/<短名>` / `chore/<短名>` / `refactor/<短名>`。
- Conventional Commits 中文主体，格式 `<type>(<scope>): <中文主体 ≤50 字>`；正文写"为什么"，引用 ADR/issue。
- 一个 commit 只做一件事。
- 3D 模型与 ≥1MB 位图走 Git LFS；SVG 不走 LFS。
- 禁止入 git：`.godot/` 缓存、`.pcbotlib.sqlite`、`.pcbot/last-run.json`、`.pcbot/commit-msg`、绝对路径、密钥。

## 做新功能时的检查清单

1. 命令可通过 CLI 触达？（有对应 `Runtime/modules/<domain>/commands.gd` 注册项）
2. 坐标全部 `int64` nm？
3. 错误走 `Result`，错误码落在 `Runtime/core/error.gd`？
4. 对应 `docs/skills/<domain>/<method>.yaml` 更新？
5. `tests/unit/<mirror>_test.gd` 至少一个 smoke + 一个边界用例？端到端触达 `tests/integration/led_blink_e2e_test.gd`？
6. 新增持久化文件？先写 ADR（`docs/architecture/ADR-XXXX-*.md`）。

## 参考文档

- [架构设计](docs/architecture/架构设计.md)
- [代码规范](docs/conventions/代码规范.md) / [文档规范](docs/conventions/文档规范.md)
- [M1 实现计划](docs/plan/实现计划-M1.md)
- ADR 目录：[docs/architecture/](docs/architecture/)
