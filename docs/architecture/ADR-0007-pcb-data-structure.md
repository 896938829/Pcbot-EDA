# ADR-0007 · PCB 层叠 + Trace / Via 数据结构

| 字段 | 值 |
| --- | --- |
| 状态 | proposed |
| 日期 | 2026-04-23 |
| 作用域 | M2+ |

## 背景

[实现计划-M2 §4 P3](../plan/实现计划-M2.md) 要落 `*.pcb.json` 数据模型。M1 系列的原理图侧 `*.sch.json` 已有稳定形式（[架构设计 §4](架构设计.md)），但 PCB 侧 `Pcb` / `Stackup` / `FootprintPlacement` / `Trace` / `Via` 字段命名与结构尚未定义。

关键设计约束（[CLAUDE.md 架构铁律](../../CLAUDE.md)）：

1. 坐标全 `int64` nm（无 float 跨模块 API）
2. JSON 稳定序列化（键字典序、2 空格、LF）
3. 顶层带 `format_version`
4. 字段命名为未来 KiCad 互操作（M4）留余地

待决策点：

- 层叠（stackup）是按"层名 list"还是"层 ref + 几何属性 dict"？
- Trace 端点用"两点 segment"还是"polyline 折线"？
- Via 用"独立顶层条目"还是"嵌入 trace 节点"？
- net_id 全局字符串还是工程内整数？

## 决策

### 层叠（Stackup）

```json
{
  "format_version": 1,
  "layers": [
    {"id": "top",         "type": "signal",      "thickness_nm": 35000},
    {"id": "top_silk",    "type": "silkscreen",  "thickness_nm": 0},
    {"id": "top_mask",    "type": "soldermask",  "thickness_nm": 0},
    {"id": "core",        "type": "dielectric",  "thickness_nm": 1600000, "er": 4.4},
    {"id": "bottom",      "type": "signal",      "thickness_nm": 35000}
  ]
}
```

- 层名固定字符串 id（`top` / `bottom` / `inner_1` / `inner_2` / `top_silk` / `top_mask` / `top_paste` / `bottom_*` / `top_courtyard` / `top_assembly`）
- `type` 枚举：`signal` / `dielectric` / `silkscreen` / `soldermask` / `paste` / `courtyard` / `assembly`
- M2 仅支持 2 层 + 4 层固定模板；任意层叠延 M3+

### FootprintPlacement

```json
{
  "uid": "fp_0001",
  "footprint_ref": "library://generic/SOIC-8",
  "pos_nm": [10000000, 5000000],
  "rotation_deg": 90,
  "side": "top",
  "reference": "U1"
}
```

- `pos_nm` 是 `[int64, int64]` —— 焊盘原点中心
- `rotation_deg` 仅允许 `0` / `90` / `180` / `270`（M2 范围）
- `side` 枚举：`top` / `bottom`（镜像由 `side=bottom` 隐式表达，不另设 `mirror` 字段）

### Trace（走线）

```json
{
  "uid": "tr_0001",
  "layer": "top",
  "net_id": "VCC",
  "width_nm": 250000,
  "points_nm": [[0, 0], [10000000, 0], [10000000, 5000000]]
}
```

- 用 **polyline 折线**（不是离散 segment list）—— 减少节点数，方便 hit-test 与 DRC
- 折线节点至少 2 个；M2 仅强制相邻节点轴对齐（90°）；任意角度延 M3
- `net_id` 直接复用 `Schematic` 的 net 名（全局字符串 SSOT，不另设整数 id）

### Via

```json
{
  "uid": "via_0001",
  "pos_nm": [10000000, 5000000],
  "net_id": "GND",
  "drill_nm": 300000,
  "diameter_nm": 600000,
  "from_layer": "top",
  "to_layer": "bottom"
}
```

- **顶层独立条目**（不嵌 trace） —— DRC 与渲染独立查询更高效；trace 可"挂"到 via 通过 `points_nm` 端点重合判定
- M2 仅支持通孔 via（`top` ↔ `bottom`）；盲孔 / 埋孔延 M3+

### 顶层 PCB 文件

```json
{
  "format_version": 1,
  "board": {
    "outline_nm": [[0, 0], [50000000, 0], [50000000, 50000000], [0, 50000000]],
    "origin_nm": [0, 0]
  },
  "stackup": { ... },
  "placements": [ ... ],
  "traces": [ ... ],
  "vias": [ ... ]
}
```

- `outline_nm` 闭合 polygon（首尾不重复，渲染时自动闭合）
- 全顶层键字典序：`board` / `format_version` / `placements` / `stackup` / `traces` / `vias`

### KiCad 互操作映射约定

- `pad_type` 取值与 KiCad 一致：`smd` / `thru_hole` / `np_thru_hole` / `connect`
- `shape` 取值：`circle` / `rect` / `oval` / `roundrect`
- `drill_nm` 0 表示无钻孔
- M4 互操作转换器只做"字段重命名 + 单位换算"，不做语义重映射

## 影响

### 正面

- M2 数据落地有客观目标，跨 P2/P3/P4 团队对齐
- 折线 + 独立 via 结构利于 DRC 与渲染（M3 R-Tree 加速也基于此）
- KiCad 互操作（M4）成本可控

### 约束

- 任意角度走线 / 多层叠 / 盲埋孔在 M2 拒绝（命令侧返回 `PCB_UNSUPPORTED_GEOMETRY`）
- `format_version: 1` 升级时必须附 `Runtime/io/migrations/v1_to_v2.gd`
- net_id 字符串方案要求 schematic 改 net 名时跨文件级联更新（CLI `schematic.rename_net` 推 M3）

### 不变

- 坐标 nm / `Result` 错误 / 中间文件白名单 / `EventBus` 路由 等铁律不变

## 验收

- `*.pcb.json` 与 `*.fp.json` round-trip 字节一致
- M2 P3 / P4 单测覆盖 4 种基本 net 拓扑
- M2 P5 DRC 6 条规则全部基于本结构实现，无字段偏差
- KiCad 字段映射表落 `docs/specs/2026-04-23-pcb-layout-format.md`

## 备选方案

- **方案 B：trace 用离散 segment list** — 否决，节点冗余多 2-4 倍，DRC 几何遍历更慢
- **方案 C：via 嵌入 trace 节点** — 否决，DRC 短路检测要 join 两边 net，复杂度上升
- **方案 D：net_id 用整数 id + name lookup 表** — 否决，schematic 侧已用字符串 SSOT，引入 lookup 表是双源
- **方案 E：M2 直接支持任意角度走线** — 推迟，几何复杂度（线段相交 / 弧线）超出 M2 工期

## 触发重审本 ADR 的条件

任一项满足即新 ADR 续约：

1. 用户需求出现任意角度 / 弧线走线
2. KiCad 互操作 M4 实测发现字段映射不可逆
3. M3 多层叠（≥6 层）需求落地

## 参考

- [实现计划-M2 §4 P3](../plan/实现计划-M2.md)
- [架构设计 §4](架构设计.md)
- [需求整理 §二.3](../需求整理.md)
- [CLAUDE.md 架构铁律](../../CLAUDE.md)
