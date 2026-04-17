# GUT 安装说明

本目录是 [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) 的放置点。
为了保持仓库小巧，GUT 本体不入 git，需要执行者首次拉取：

```bash
# 选项 A：子模块（推荐长期维护）
git submodule add https://github.com/bitwes/Gut.git addons/gut

# 选项 B：下载 release 并解压到 addons/gut/
```

启用：Godot 编辑器 → 项目设置 → 插件 → GUT → 启用。

跑测试：

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```

> 本仓库提供 `tests/lightweight_runner.gd` 作为备用：在未装 GUT 时运行最小单测，
> 保证"克隆即可跑一遍核心用例"，供 CI 与 M1 演练使用。
