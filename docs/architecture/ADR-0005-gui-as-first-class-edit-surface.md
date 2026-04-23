# ADR-0005 · GUI 是一等编辑面

| 字段 | 值 |
| --- | --- |
| 状态 | accepted |
| 日期 | 2026-04-22 |
| 作用域 | M1.2+ |

## 背景

M1 / M1.1 [架构设计 §1.2](架构设计.md) 与 [CLAUDE.md 架构铁律](../../CLAUDE.md) 第一条
写的是"**编辑器不内置 AI 推理**：无 LLM 调用、无本地模型"与"**AI 设计、人类审核**：
任何设计操作必须有 CLI 对应方法；纯 GUI-only 功能禁止。"

两条合在一起被执行者（含 AI Agent 与人类贡献者）误读为"GUI 仅做被动渲染，禁止人类通过 GUI
编辑设计"。直接后果：M1 / M1.1 落地时 [Scenes/Main.tscn](../../Scenes/Main.tscn) 止步于
"新建 / 打开 / 载 demo"三个按钮 + 两个文字 Label；[Runtime/ui/schematic_view.gd:109](../../Runtime/ui/schematic_view.gd#L109)
还潜伏一个 `component_id` vs `component_ref` 字段错配 bug，demo 打开后 7 个元件**全部**
回退到"无符号纹理"蓝方块 —— 人类**无法 Review AI 的设计成果**。

"AI 设计、人类审核"若没有"人类用 GUI 看图 / 选元件 / 改 reference / 调位置 / 补连线 / 查日志"
这些能力，等于空话。当前表述需要澄清，否则 M1.2 全部 GUI 编辑工作会再次被铁律的字面语义阻塞。

## 决策

M1.2 起确立以下原则：

1. **GUI 是一等编辑面**：人类贡献者通过 GUI 触发设计变更是被架构支持的首选路径；
   CLI 是 AI Agent 的首选路径。GUI 与 CLI 地位对等。
2. **共用领域服务**：GUI 编辑动作**必须**经 `Runtime/modules/<domain>/commands.gd` 注册的
   CLI 方法（与 AI Agent 走同一个 `CommandRegistry` dispatch / 同一个 `Result` 反馈 /
   同一份 `.pcbot/last-run.json` / 同一份 `.pcbot/commit-msg` 产出）。**禁止** GUI 直接
   `JsonStable.write_file(...)` 或绕过 `Result` 改动持久化状态。
3. **编辑器不嵌入 AI 推理**：此条约束**保留**且不松动 —— 无 LLM 调用、无本地模型、
   无 AI 决策树 UI。CLI 仍是 AI 的唯一接入面。
4. **撤销 / 重做基于 CLI 命令栈**：GUI 侧 undo stack 记录已执行 CLI 命令的
   `{forward, inverse}` 对，不记录文件 diff、不落盘、跨工程切换时清空。
5. **内存模型被动**：GUI 内存中的 `Schematic` 等领域对象不是第二条状态河 —— 每次成功 CLI
   调用后按需重新从文件加载，以文件系统为 single source of truth。

## 影响

### 正面

- 人类 Review AI 设计的工作流可行（选元件、看属性、改 reference、拖位置、补连线）。
- AI Agent 与人类贡献者走同一套命令、同一套 Skills YAML，文档与测试不需双份。
- 审计友好：每一次 GUI 编辑都在 `.pcbot/last-run.json` 留痕，同 CLI。

### 约束

- 所有新的"编辑性"功能都必须先在 `Runtime/modules/<domain>/commands.gd` 注册 CLI 方法，
  再由 GUI 调用。GUI-only 的"隐藏"编辑能力**禁止**。
- M1.2 后续 phase 要**新增**的 CLI 方法（不完全清单，见 [实现计划-M1.2](../plan/实现计划-M1.2-GUI完善.md)）：
  - `schematic.move_placement`
  - `schematic.remove_placement`
  - `schematic.remove_net`
  - `schematic.set_property`
  - `schematic.rotate_placement`
  - `schematic.disconnect_pin`
- CLI 调试面板（M1.2 P6）在 GUI 内同进程复用 `CommandRegistry`，走相同方法注册 —— **不得**
  为 GUI 创建影子 registry 或绕过 `Result`。
- 错误边界仍在 CLI 方法内部：GUI 不抛异常穿越模块边界，不自行拼装 JSON-RPC 响应，
  全部经 `Result.ok/err` + `cli/jsonrpc.gd` 映射。

### 不变

- [CLAUDE.md](../../CLAUDE.md) "架构铁律"其他条款（模块边界、I/O 分层、坐标 nm、错误 Result、
  日志 Logger）**全部保留**。
- `.pcbot/` 白名单（`last-run.json` / `diagnostics.jsonl` / `commit-msg`）不因 GUI 编辑能力
  扩张而新增文件；新增须走新 ADR。

## M1.2 / M1.2.1 实装纪要

截至 2026-04-23（M1.2 stable + M1.2.1 GUI 修复收敛）：

- **新增 CLI 方法**（决策 §约束 清单全部落地）：`schematic.move_placement` /
  `remove_placement` / `remove_net` / `set_property` / `rotate_placement` /
  `disconnect_pin`。全部在 `Runtime/modules/schematic/commands.gd::register`。
- **UndoStack 覆盖**（`Runtime/ui/undo_stack.gd`）：8 个编辑命令的 forward/inverse
  已齐——`place_component` / `move_placement` / `rotate_placement` / `set_property`
  （M1.2 P13）+ `remove_placement` / `connect` / `disconnect_pin`（M1.2.1 P7）。
  inverse 中 `remove_placement` 通过 Result.data 的 `placement_snapshot` + `net_snapshots`
  重建（新 uid，pin ref 按 reference.number 寻址）；`connect` 按 `is_new` / `added_pins`
  走 `remove_net` 或 `disconnect_pin`。
- **UI 组件清单**（`Runtime/ui/`）：`main_window.gd` / `schematic_view.gd` /
  `properties_panel.gd` / `library_panel.gd` / `log_viewer.gd` / `status_bar.gd` /
  `cli_console.gd` / `undo_stack.gd`。CliConsole 在进程内复用同一 `CommandRegistry`
  + 全部 `*Commands.register`，无影子 registry。
- **UI 与落盘联动**：`EventBus.schematic_disk_changed(path)` 作为"落盘后通知"信号，
  `SchematicView._ready` 订阅；无法直接持 view 引用的 `PropertiesPanel` 改文件后
  emit 该信号触发 reload。详见 [架构设计 §9](架构设计.md#9-事件总线)。
- **格式/尺寸**：SVG 渲染 `SvgIO.render_symbol` 支持 `bbox_nm` 全零时按 pins 推导
  viewbox，向后兼容非零 bbox 符号。
- **未入 M1.2.1 的 GUI 能力**（推 M2）：框选 / net / wire 选中高亮 / 旋转 placement
  的引脚坐标 2D 仿射变换 / 多 schematic tab / 跨 placement 剪贴板 /
  `.sym.svg` 独立美化图形。

## 触发重审本 ADR 的条件

任一项满足即需要新 ADR 更替或补充：

1. 需要在 GUI 内嵌 LLM 调用或本地模型（违反决策第 3 条）。
2. 需要在 GUI 侧引入 CLI 无对应的"纯 GUI"编辑动作。
3. 需要把 GUI 内存模型升级为独立状态源（如实时协作场景，文件系统不再是 SSOT）。

## 参考

- [实现计划-M1.2 §1 背景与定位修正](../plan/实现计划-M1.2-GUI完善.md)
- [架构设计 §1.2](架构设计.md)
- [ADR-0004 不引入 DI 容器](ADR-0004-no-di-container-in-m1.md)
- [CLAUDE.md 架构铁律](../../CLAUDE.md)
