# Perf Baseline · M1.1

| 字段 | 值 |
| --- | --- |
| 日期 | 2026-04-21 |
| Commit | 9a00c88（P3 完工） |
| 机器 | Windows 10 Pro 10.0.19045 |
| Godot | 4.6.2.stable.official.71f334935 |
| 库索引 | JSON 扫描（P2 SQLite 尚未落地；见 DEFERRED） |
| Runner | `godot --headless -s tests/perf_runner.gd` |

---

## 基线数值

| 场景 | 指标 | 架构 §10 目标 | 实测 | 达标 |
| --- | --- | --- | --- | --- |
| 元件库搜索（10k 条，冷） | `library_index.search("rare_string")` | < 100 ms | 15 ms | ✓ |
| 元件库搜索（10k 条，热） | `library_index.search("Vishay")` | < 100 ms | 14 ms | ✓ |
| 元件库加载（10k 条扫 JSON） | `LibraryIndex.load_from_root` | 无硬指标 | 701 ms | — |
| schematic round-trip（1k 放置 / 5k 网络） | 第二次写入 | < 200 ms | 233 ms | ✗（余量 +16%）|
| schematic round-trip 字节稳定性 | write1 == write2 bytes | 必须字节一致 | 严格一致 | ✓ |
| check.basic（1k 放置 / 500 网络） | 单次耗时 | < 50 ms | 69 ms | ✗（余量 +38%）|

## 观察

- **library search 显著优于 SQLite 目标**：JSON 扫描 + Array 遍历在 10k 量级下仍 < 20 ms；P2 切 SQLite 的主要收益在加载时间（701 ms → 预期 <50 ms）与复合查询能力，非 search 本身。
- **sch round-trip 超标 16%**：主要开销在 JSON 稳定序列化的字典排序。M2 需考虑增量写或二进制中间态（但会破坏 git diff 可读性——权衡留给 M2）。
- **check.basic 超标 38%**：当前 O(P × N) 扫描（每元件查每网络）。加空间索引 / pin_to_placements 倒排表可轻易达标；M2 DRC 扫描改写时顺带修。

## 复现步骤

```bash
# 首次运行会生成 ~10.2k 个 JSON fixture 到 user://perf_lib_10k/（持久化缓存）。
# 后续运行直接复用该缓存；若需要重生，手动删除该目录。
godot --headless --import     # 保证 class_name 已注册
godot --headless -s tests/perf_runner.gd
```

## 阈值策略

- M1.1：**不做硬断言**（perf 测试通过不代表达标）。本文件数值作为 M2 CI 回归初值。
- M2 CI：以本基线的 **1.2×** 为红线（容忍 20% 环境抖动）。超过即挂 fail；以 `commit` 为锚做 bisect。

## Follow-ups

- P2 SQLite 落地后，重跑本基线覆盖写 library 段。
- sch round-trip / check.basic 达标修正可在 M2 DRC 空间索引工作一并做。
- 新增 perf 用例时：同步更新本文件；保持表格与实际 `tests/perf/*_perf_test.gd` 一一对应。
