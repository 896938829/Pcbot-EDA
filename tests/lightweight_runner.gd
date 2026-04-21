extends SceneTree

## 轻量测试入口（不依赖 GUT）。
## 运行：godot --headless -s tests/lightweight_runner.gd
## 约束：每个 *_test.gd 暴露 `static func run() -> Array`，返回 [{name, ok, msg}]。

const TESTS: Array = [
	"res://tests/unit/unit_system_test.gd",
	"res://tests/unit/json_stable_test.gd",
	"res://tests/unit/jsonl_test.gd",
	"res://tests/unit/yaml_test.gd",
	"res://tests/unit/result_test.gd",
	"res://tests/unit/component_symbol_test.gd",
	"res://tests/unit/svg_export_test.gd",
	"res://tests/unit/schematic_test.gd",
	"res://tests/unit/schematic_annotate_test.gd",
	"res://tests/unit/library_index_test.gd",
	"res://tests/unit/run_report_test.gd",
	"res://tests/unit/diagnostics_log_test.gd",
	"res://tests/unit/command_registry_test.gd",
	"res://tests/integration/led_blink_e2e_test.gd",
	"res://tests/integration/cli_stdin_test.gd",
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
	print("%d tests, %d failed, %d passed, %d ms" % [total, failed, total - failed, elapsed])
	quit(1 if failed > 0 else 0)
