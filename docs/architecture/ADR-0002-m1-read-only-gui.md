# ADR-0002 · M1 GUI 保持只读渲染

| 字段 | 值 |
| --- | --- |
| 状态 | superseded by [ADR-0005](ADR-0005-gui-as-first-class-edit-surface.md)（2026-04-22） |
| 日期 | 2026-04-17（废止 2026-04-22） |
| 作用域 | M1（M1.0 有效；M1.1 起废止） |

> **废止说明（2026-04-22）**：M1.1 完成后评估 AI-only 设计流程不足以覆盖
> 快速原型 / 手动微调需求，遂改走 ADR-0005 的"GUI 为一等编辑面"方案。
> M1.2 实装 CLI 调试面板、属性面板、placement 拖拽 / 旋转 / 删除、wire
> 连接、Undo/Redo。本 ADR 保留以便追溯 M1.0 的决策脉络。

## 背景

[AI 设计哲学](../AI设计哲学.md) 明确：编辑器被动响应 AI，不内置 AI 推理。
M1 时间预算下无法同时把 CLI 与 UI 编辑都打磨完整。

## 决策

M1 的 UI：
- `Scenes/Main.tscn` 提供打开 `*.pcbproj` 的入口
- `Runtime/ui/schematic_view.gd` 仅绘制元件轮廓 + 网络连线 + 网格 + 缩放/平移
- 不提供拖拽、连线、编辑属性等交互

设计编辑全部走 CLI（JSON-RPC）。

## 影响

- 满足 DoD "人类审核者用 Godot 打开 `demo/led_blink.pcbproj` 能看到原理图"。
- M2+ 补 UI 交互时直接在 `Runtime/ui/` 下扩展，不触及 CLI / modules。

## 参考

- [AI 设计哲学](../AI设计哲学.md)
- [实现计划-M1 §3 P7](../plan/实现计划-M1.md)
