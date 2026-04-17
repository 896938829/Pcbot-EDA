# ADR-0001 · 元件库索引在 M1 用 JSON 扫描替代 SQLite

| 字段 | 值 |
| --- | --- |
| 状态 | accepted |
| 日期 | 2026-04-17 |
| 作用域 | M1 |

## 背景

[架构设计 §4](架构设计.md) 与 [实现计划-M1 §3 P6](../plan/实现计划-M1.md) 规定元件库索引
用 SQLite 实现（`.pcbotlib.sqlite`）。Godot 4 内置不含 SQLite，社区方案
（`godot-sqlite` GDExtension）需额外二进制构建与 C++ 工具链。

M1 的库规模 ≤ 几十条，JSON 扫描足够快（< 50 ms）。引入 GDExtension 二进制会
把"克隆即能跑"的成本抬得很高，违背 M1 最小可用原则。

## 决策

M1 范围内：

- `LibraryIndex`（[Runtime/modules/library/library_index.gd](../../Runtime/modules/library/library_index.gd)）
  在内存里直接扫目录，构造 Array/Dictionary 索引。
- `library.list / library.search / library.add_*` 行为与 SQLite 版接口保持一致。
- 查询 API 字段（`part_number / manufacturer / id / description`）与将来的
  SQLite 列一致，方便平滑切换。

## 影响

- 性能目标 [架构设计 §10](架构设计.md#10-性能红线m1-目标) 中"元件库搜索 10k 条 < 100 ms"
  在 M1 不做验证；M2 切 SQLite 时作为门禁指标。
- `.pcbotlib.sqlite` 相关文件路径保留在 `.gitignore`，避免将来切回时需改忽略规则。
- 不引入任何 SQLite GDExtension 依赖，不动 `addons/`。

## 触发切换的条件（M2 决策点）

任一项满足即切回 SQLite：

1. 元件库 ≥ 1000 条且搜索出现感知延迟。
2. 需要复合查询（多字段 AND / OR、范围过滤）。
3. 多工程共享中心库时出现并发扫描瓶颈。

## 参考

- [实现计划-M1 §3 P6](../plan/实现计划-M1.md)
- [架构设计 §4](架构设计.md)
