class_name LibrarySearchPerfTest
extends RefCounted

## P5：元件库搜索性能基线（10k 库条目）。
## M1.1 阶段 LibraryIndex 走 JSON 扫描；P2 切 SQLite 后阈值收紧到 100 ms（架构 §10）。
## 当前阶段不做硬阈值，记录数值入 BASELINE.md。


static func _ms(fn: Callable) -> int:
	var t0 := Time.get_ticks_msec()
	fn.call()
	return Time.get_ticks_msec() - t0


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("library_search_10k_baseline", func():
		var root := "user://perf_lib_10k"
		if not DirAccess.dir_exists_absolute(root):
			GenLib.gen(root, 200, 10000)
		var idx := LibraryIndex.new()
		var loaded_ms := _ms(func(): idx.load_from_root(root))
		var hits: Array = []
		var search_ms := _ms(func(): hits = idx.search("rare_string"))
		var hot_ms := _ms(func(): idx.search("Vishay"))
		print("[PERF] library load %d ms; cold search %d ms; hot search %d ms" % [loaded_ms, search_ms, hot_ms])
		## 不做硬断言：M1.1 路径性能由 BASELINE.md 记录。
		if loaded_ms <= 0 or hot_ms < 0:
			return "non-monotonic timing"
		return ""))
	return r
