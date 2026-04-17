# ADR-0003 · M1 测试双轨：轻量 runner + GUT 备选

| 字段 | 值 |
| --- | --- |
| 状态 | accepted |
| 日期 | 2026-04-17 |
| 作用域 | M1 |

## 背景

[实现计划-M1 §3 P1](../plan/实现计划-M1.md) 规划引入 GUT 插件，但 GUT 本体体量大，
作为外部依赖不入 git（见 [addons/gut/README.md](../../addons/gut/README.md)），
首次克隆仓库的贡献者跑不了测试。

## 决策

同时保留两种测试入口：

- **轻量 runner**：`tests/lightweight_runner.gd`，纯 GDScript 无插件依赖。
  每个 `*_test.gd` 暴露 `static func run() -> Array`。
- **GUT**：执行者本地装 `addons/gut/` 后跑 `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`。

两套 runner 读同一批测试脚本；断言工具 `tests/assert_util.gd` 做兼容层。
M1 合并门禁以轻量 runner 为准；M2 起切 GUT 并加覆盖率门禁。

## 影响

- "克隆即可跑测试"成立。
- GUT 专属特性（参数化、mock、场景测试）延后到 M2 使用。
- 测试代码需保持"两个 runner 都能跑"的纪律：不依赖 GUT-only API。

## 参考

- [实现计划-M1 §3 P1 / P9](../plan/实现计划-M1.md)
- [代码规范 §9](../conventions/代码规范.md#9-测试要求m1)
