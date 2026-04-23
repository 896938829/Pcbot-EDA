# ADR-0008 · 元件库继续用 JSON，否决 SQLite 切换

| 字段 | 值 |
| --- | --- |
| 状态 | proposed |
| 日期 | 2026-04-23 |
| 作用域 | M2+ |
| 续约 | [ADR-0001](ADR-0001-library-index-json-scan.md)（SQLite 切换分支 superseded） |

## 背景

[ADR-0001](ADR-0001-library-index-json-scan.md) M1 阶段决策"元件库索引在 M1 用 JSON 扫描替代 SQLite"，并在"触发切换的条件"列出三条触发器：

1. 元件库 ≥ 1000 条且搜索出现感知延迟
2. 需要复合查询
3. 多工程共享中心库出现并发瓶颈

M2 规划讨论中，触发器 1 已接近边界（[资源清单](../资源清单.md) M2 阶段引入 SQLite GDExtension）。但用户 2026-04-23 评审时明确否决 SQLite 切换，理由：

1. **SQLite 二进制文件不利 git 版本管理**：`.pcbotlib.sqlite` 即使可用本地缓存形式（`.gitignore`），但若任何场景需入 git（中心共享库 / 离线分发）则 diff 不可读、合并冲突无法解决
2. **增加项目复杂度**：godot-sqlite GDExtension 依赖跨平台二进制（Windows / Linux / macOS）；与 JSON 扫描双路径维护，测试矩阵翻倍
3. **违背仓库核心原则**："源文件即 SSOT / Git 友好 / 稳定序列化"（[工程文档 §2](../工程文档.md)）；SQLite 路径与之冲突

## 决策

M2+ 元件库索引方案：

1. **继续 JSON 扫描** —— `Runtime/modules/library/index.gd` 按目录扫，构造 Array/Dictionary 索引；不引 SQLite
2. **性能加固**（M2 P1）：
   - 内存索引：按 `manufacturer` / `part_no` / `category` 多键 hash
   - 文件 mtime 增量扫描（启动时 / 文件变更时局部刷新）
   - 性能基线：1500 条 JSON 库 `library.search` < 200ms
3. **缓存策略**：默认**不**新增缓存文件（启动全扫 1500 条 < 100ms 可接受）。若性能基线不达，再走单独 ADR 评估扩 `.pcbot/` 白名单
4. **撤销 ADR-0001 触发器 1**：元件库 ≥ 1000 条不再自动触发 SQLite 切换；改为本 ADR §"触发重审条件"
5. **撤销资源清单 SQLite 启用项**：[资源清单](../资源清单.md) M2 阶段移除 godot-sqlite GDExtension 条目

## 影响

### 正面

- `*.json` 元件文件继续 git diff 友好，合并冲突可解
- 项目依赖最小化，"克隆即能跑"原则继承自 M1
- AI Agent / 人类贡献者无需理解 SQLite schema，直接读 JSON
- 测试矩阵无 SQLite 二进制平台变量

### 约束

- 元件库 ≥ 5000 条时性能可能退化（M2 P1 基线只到 1500）；触发本 ADR 重审
- 复合查询（多字段 AND/OR / 范围过滤）能力受限于 GDScript 内存索引；无 SQL 表达力
- 多工程共享中心库（M3+）若并发扫描出现瓶颈，需重审

### 不变

- ADR-0001 §"决策"部分（JSON 扫描接口、字段命名）保留，仅 SQLite 切换分支 superseded
- M1 库相关 CLI 命令签名（`library.list` / `library.search` / `library.add_component`）行为不变

## 验收

- M2 P1 实装 `Runtime/modules/library/index.gd`，1500 条种子库 `library.search` < 200ms（`tests/perf/library_baseline.gd` 验证）
- 资源清单 M2 阶段移除 SQLite 项，标"已否决，参见 ADR-0008"
- ADR-0001 顶部加 `状态: superseded（SQLite 切换分支） → ADR-0008`
- M2 启动后 ≥3 个月，元件库 ≥3000 条时性能复测，结果落 `docs/specs/<date>-library-perf-review.md`

## 备选方案

- **方案 B：M2 切 SQLite**（ADR-0001 原触发器路径） — **用户 2026-04-23 否决**，理由见背景 §1-3
- **方案 C：JSON + DuckDB 嵌入式 OLAP** — 否决，复杂度更高且 Godot 生态无成熟绑定
- **方案 D：保持 ADR-0001 现状，不做性能加固** — 否决，1000+ 条搜索延迟 ≥500ms 不可接受

## 触发重审本 ADR 的条件

任一项满足即新 ADR 续约：

1. 元件库 ≥ 5000 条且 `library.search` 实测 ≥500ms（M2 性能基线 < 200ms 退化 2.5 倍）
2. 用户场景出现强复合查询需求（多字段 AND/OR / 范围 / 全文检索）
3. 多工程共享中心库 + 并发扫描成为瓶颈
4. 用户主动撤回本决策

## 参考

- [ADR-0001](ADR-0001-library-index-json-scan.md)（SQLite 切换分支 superseded）
- [实现计划-M2 §4 P0/P1](../plan/实现计划-M2.md)
- [工程文档 §2](../工程文档.md)
- [资源清单](../资源清单.md)
