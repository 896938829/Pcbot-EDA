# ADR-0002 · M1 GUI 保持只读渲染

| 字段 | 值 |
| --- | --- |
| 状态 | accepted |
| 日期 | 2026-04-17 |
| 作用域 | M1 |

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
