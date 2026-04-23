# UI 手验清单（M1.2）

每次改 GUI 后跑一遍。Headless 测试无法覆盖 UI，故须人工。

> **M1.2.1 修复状态（2026-04-23）**：下表 [X] 标记的 7 类缺陷已按
> `docs/plan/实现计划-M1.2.1-GUI修复.md` 修复并跑过单元 / 集成 /
> GUT 全绿（65 + 15 测试通过）。**GUI 端复跑待人工**，复跑通过后
> 把对应项 [X] 改 [✔] 并删掉 `*` 开头的评注行。

## 启动

- [✔] F5 → 主窗口出现，MenuBar + 4 dock + StatusBar 全在
- [✔] 文件菜单：新建 / 打开 / 载入 Demo / 最近工程（初次空）/ 退出
- [✔] 编辑菜单：撤销 / 重做 / 删除选中
- [✔] 视图菜单：左 / 右 / 底 dock 三个 check 项，网格 check 项
- [✔] 帮助菜单：关于（显示版本）
- [✔] 状态栏 5 列：工程 / zoom% / (— , —) mm / 未选中 / 空 last-run

## 载入 demo

- [✔] 文件 → 载入 Demo
- [✔] 中央 SchematicView 显示 **真 SVG 符号**（NE555 / R-10k / R-330 / C-10uF / LED / VCC / GND），不是蓝方块
- [✔] 7 个引脚小黄点分布在符号两侧
- [✔] 左 dock 列出 7 个 components + 7 个 symbols
- [✔] 库搜索框输入 "LED" → 只剩 1 条 LED
- [✔] 日志 tab 订阅 Logger；Diagnostics / Last Run tab 可切
- [✔] StatusBar 工程列显示 "LED Blink · 元件 8 · 网络 6 · 库引用 1"（实际输出按 project.name）

- 评：NE555左边引脚排列正常，右边排列分散。只有表示引脚的点，没有电阻、电容、电源、地、芯片等图像。

## 鼠标交互

- [✔] 鼠标移动 → StatusBar mouse mm 列实时更新
- [✔] 滚轮缩放 → StatusBar zoom% 更新
- [✔X] 右下角 +/−/100%/Fit/网格 按钮点击 → 符合直觉 * 网格右下角百分比还没有更新
* 点击- +有效，但是百分比没有更新
- [✔] 中键拖动 → 画布 pan
- [✔] 鼠标悬停 placement → 黄色描边
- [✔] 左键点 placement → 橙色描边 + 右 dock 属性面板显示字段

## 编辑

- [✔] 左 dock 组件 → 拖到 view → 新 placement 出现，reference 自动 R1/C1/...
* Demo工程电阻从R4开始、电容C2开始，怀疑是工程中的默认原理图没有显示出来
- [✔] 选中 → 左键按下 → 拖动 → 松开，placement 移位（文件落盘）
- [✔] 属性面板改 reference → 回车 → StatusBar 显示 "reference = ..."
- [X] 属性面板旋转 → 符号转 90°
* 更改后未旋转，回车确认会和打开下拉菜单冲突
- [✔] Del 键 → 选中 placement 消失
- [✔] 点第一个 pin → 绿色高亮 + 虚线跟随鼠标
- [✔X] 点第二个 pin → 虚线消失，新 net 出现（wire 画出）
* 出现了连接的黄线，但是黄线只会从第一个引脚连出去，切黄线无法选中
- [✔] Escape → 取消 wiring

## 撤销 / 重做

- [✔] Ctrl+Z 连续 3 次 → 回退最后 3 次编辑
- [✔] Ctrl+Y 连续 3 次 → 前进
- [✔] 切换工程 → undo 栈清空

## CLI 调试面板

- [X] 输入合法 JSON-RPC `{"jsonrpc":"2.0","id":1,"method":"check.basic","params":{"schematic":"<demo sch>"}}` → 绿色响应
- 没有输出绿色
- [X] 输入错误 method → 红色响应 + 可见方法列表
- 没有输出红色
* 相应有代码，但是没有显示颜色
- [✔] Up/Down 方向键 → 调取历史

## 持久化

- [✔] 关闭 dock → 退出 → 重开：dock 状态恢复
- [✔] 最近工程菜单：载入过 demo → 出现在"最近工程"子菜单 → 可直接点开
