extends SceneTree

## perf 入口：单独 runner，避免基准抖动影响常规回归。
## 运行：godot --headless -s tests/perf_runner.gd
## 数据落入 tests/perf/BASELINE.md 由人工记录。

const TESTS: Array = [
	"res://tests/perf/library_search_perf_test.gd",
	"res://tests/perf/sch_roundtrip_perf_test.gd",
	"res://tests/perf/check_basic_perf_test.gd",
]


func _init() -> void:
	var total := 0
	var failed := 0
	var start := Time.get_ticks_msec()
	for path in TESTS:
		var script = load(path)
		if script == null:
			printerr("[LOAD FAIL] %s" % path)
			failed += 1
			total += 1
			continue
		var results: Array = script.run()
		for r in results:
			total += 1
			if bool(r.get("ok", false)):
				print("[PASS] %s :: %s" % [path.get_file(), r["name"]])
			else:
				failed += 1
				print("[FAIL] %s :: %s — %s" % [path.get_file(), r["name"], r.get("msg", "")])
	var elapsed := Time.get_ticks_msec() - start
	print("---")
	print("%d perf tests, %d failed, %d passed, %d ms total" % [total, failed, total - failed, elapsed])
	quit(1 if failed > 0 else 0)
