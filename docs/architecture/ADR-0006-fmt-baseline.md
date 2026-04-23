# ADR-0006 · gdformat baseline 与多行 lambda 写法约束

| 字段 | 值 |
| --- | --- |
| 状态 | proposed |
| 日期 | 2026-04-23 |
| 作用域 | M2 P0 起全仓 |

## 背景

[实现计划-M1.1 §3](../plan/实现计划-M1.1-债务清算.md) P6 引入 `gdtoolkit` 4.x（`gdformat` / `gdlint`）作为格式化工具链；`tools/fmt.sh` / `tools/fmt_check.sh` 已就位。但**全仓 fmt baseline 未跑**，原因：

`gdformat` 4.5 重排部分 `func():` 风格多行 lambda 后，会触发 Godot 4.6 解析器的一个已知 bug —— 重排后的 lambda 体被误识为外层语句，运行时报 `Parse Error: Expected end of statement`。该 bug 出现在 `tests/` 中若干集成测试，影响多个 `_test.gd`。

后果：

- 新代码无客观格式基线，AI Agent 与人类贡献者对"是否合规"判断不一致
- M2 起 PR diff 噪音难以避免（"是否要顺手 fmt 几个老文件"成为反复决策）
- CI 想接 `tools/fmt_check.sh` 门禁就会全红

[CLAUDE.md "格式化"章节](../../CLAUDE.md) 已记录此情况，但仅是"现状描述"，无强制约束。

## 决策

M2 P0 阶段（[实现计划-M2 §4 P0](../plan/实现计划-M2.md)）一次性清算 fmt baseline，并固化以下规则：

1. **lambda 写法约束**：GDScript 中所有 `func():` lambda **必须**单行写完。多行体的可调用对象抽为 helper（命名函数 / 静态方法 / `Callable.bind`）后再传递。
2. **baseline 一次性 commit**：P0 在独立 commit `chore(fmt): 全仓 gdformat baseline` 中跑 `tools/fmt.sh`，commit 信息正文标注"无逻辑变更"。
3. **CI 门禁**：M2 P0 完成后 `tools/fmt_check.sh` 接入 CI（GitHub Actions / 等价方案）；fmt 不绿不准合并。
4. **gdtoolkit 版本锁定**：仓库 `requirements-dev.txt` 显式 pin `gdtoolkit==4.5.*`（避免次版本升级再次撞 lambda bug）。
5. **绕 bug 检查脚本**：`tools/fmt_check.sh` 增前置扫描，若发现新增多行 `func():` lambda 直接拒绝（grep 多行 pattern + 失败提示引用本 ADR）。

## 影响

### 正面

- 全仓单一格式标准，PR diff 无 fmt 噪音
- AI Agent 写 GDScript 有客观目标（"跑 `tools/fmt_check.sh` 绿"即可）
- CI 门禁可启用

### 约束

- **新写代码禁止多行 `func():` lambda**；违例 CI 拒绝合并
- gdtoolkit 升级前需重测多行 lambda bug 是否修复，由 ADR 接续决策
- baseline commit 后 `git blame` 部分行 → P0 fmt commit；通过 `.git-blame-ignore-revs` 缓解（M2 P0 一并配置）

### 不变

- 缩进 Tab、行尾 LF、行长 ≤100 等 [代码规范](../conventions/代码规范.md) 项不变
- `gdformat` / `gdlint` 仍是工具链组成

## 验收

- `tools/fmt_check.sh` 全仓返回 0
- CI workflow 包含 fmt 步骤且为强制检查
- [代码规范](../conventions/代码规范.md) 增"lambda 必须单行"条款 + 引本 ADR
- `.git-blame-ignore-revs` 列入 baseline commit hash

## 备选方案

- **方案 B：保持现状不跑 baseline** — 否决，违背"客观目标"原则；新代码与老代码格式漂移会越拖越大
- **方案 C：换 formatter（自写 / Prettier 插件）** — 否决，gdtoolkit 是社区主流，自维护成本不值
- **方案 D：升级到 gdtoolkit 4.6+ 等 bug 修复** — 推迟，不阻塞 M2；待上游修复再独立 ADR

## 参考

- [实现计划-M1.1 §3 P6](../plan/实现计划-M1.1-债务清算.md)
- [实现计划-M2 §4 P0](../plan/实现计划-M2.md)
- [代码规范](../conventions/代码规范.md)
- [CLAUDE.md "格式化"](../../CLAUDE.md)
