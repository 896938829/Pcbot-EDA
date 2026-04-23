# ADR-0004 · M1/M1.1 不引入 DI 容器

| 字段 | 值 |
| --- | --- |
| 状态 | accepted |
| 日期 | 2026-04-19 |
| 作用域 | M1 / M1.1 |

## 背景

[架构设计 §2](架构设计.md) 早期草稿在核心层列出 `Runtime/core/di.gd`（"轻量依赖注入容器"），
[实现计划-M1.1 §P7](../plan/实现计划-M1.1-债务清算.md) 将其作为债务项之一：要么实现，要么删除。

实际代码状态：M1 落地后**没有任何模块**真的需要 DI 容器。`cli/main.gd::_register_all` 在入口
处显式构造 `ProjectCommands / SymbolCommands / LibraryCommands / SchematicCommands /
CheckCommands / SkillsCommands / RunCommands` 并调用各自的 `register()`；UI 同样在 `Runtime/ui/main_window.gd`
入口处显式装配。模块间需要的协作通过 `Runtime/core/event_bus.gd` 完成。
现存代码里 `grep -r "di\." Runtime cli` 零命中。

## 决策

M1 / M1.1 范围内：

- **不实现** `Runtime/core/di.gd`，对应行从 [架构设计 §2](架构设计.md) 删除。
- 模块装配统一遵循以下两种方式之一：
  - **入口显式注入**：在 `cli/main.gd` 或 UI 入口处构造服务并显式传递（构造参数或 setter）。
  - **事件总线**：`EventBus` 作为单例 Autoload，承担跨模块通知与广播。
- 测试中需要替换协作者时，使用以下任一手段：
  - 直接用替身实例传给被测对象（构造参数注入）。
  - 临时覆盖 Autoload（`get_tree().root.add_child(replacement)` 模式），测试结束清理。

## 影响

- 架构文档与实际代码一致；不再有"挂空名"的核心层条目。
- 模块作者新增服务时，**不引入**全局查找表或字符串键注册中心；服务的提供方与消费方在调用图中显式可见。
- 测试样板更轻：无需先注册再解析，构造时即装配。
- 对应回退条件：见下节"触发引入 DI 的条件"。

## 触发引入 DI 容器的条件（M2+ 重新评估）

任一项满足即重启该提案：

1. 模块数量 ≥ 12 且模块间依赖图出现明显的循环或重复装配（同一服务在 ≥ 3 处被构造）。
2. 同一服务存在 ≥ 2 个生产实现（如多种 SQLite 后端、多种 SVG 渲染器）需要按场景切换。
3. 跨进程或跨语言（C++ GDExtension）边界增加，构造期需要从配置驱动选择实现。

引入时务必同时给出：容器的 API（注册 / 解析 / 替换）、生命周期模型（singleton / scoped）、
测试样板，并以新 ADR 取代本 ADR。

## 参考

- [实现计划-M1.1 §P7](../plan/实现计划-M1.1-债务清算.md)
- [架构设计 §2](架构设计.md)
