extends GutTest

## GUT 桥接层：把现有 static func run() 风格测试套件暴露给 GUT。
## 每个原套件一个 test_* 函数，便于 GUT 报错时定位到套件。
## 原套件文件（tests/unit/*.gd, tests/integration/*.gd）保持 extends RefCounted + static run()，
## 供 tests/lightweight_runner.gd 无 GUT 环境下继续使用。


func _run_suite(path: String) -> void:
	var script = load(path)
	assert_not_null(script, "load failed: %s" % path)
	if script == null:
		return
	var results: Array = script.run()
	for r in results:
		var name := str(r.get("name", "?"))
		var ok := bool(r.get("ok", false))
		var msg := str(r.get("msg", ""))
		assert_true(ok, "%s :: %s — %s" % [path.get_file(), name, msg])


func test_unit_system() -> void:
	_run_suite("res://tests/unit/unit_system_test.gd")


func test_json_stable() -> void:
	_run_suite("res://tests/unit/json_stable_test.gd")


func test_jsonl() -> void:
	_run_suite("res://tests/unit/jsonl_test.gd")


func test_yaml() -> void:
	_run_suite("res://tests/unit/yaml_test.gd")


func test_result() -> void:
	_run_suite("res://tests/unit/result_test.gd")


func test_component_symbol() -> void:
	_run_suite("res://tests/unit/component_symbol_test.gd")


func test_svg_export() -> void:
	_run_suite("res://tests/unit/svg_export_test.gd")


func test_schematic() -> void:
	_run_suite("res://tests/unit/schematic_test.gd")


func test_schematic_annotate() -> void:
	_run_suite("res://tests/unit/schematic_annotate_test.gd")


func test_library_index() -> void:
	_run_suite("res://tests/unit/library_index_test.gd")


func test_run_report() -> void:
	_run_suite("res://tests/unit/run_report_test.gd")


func test_diagnostics_log() -> void:
	_run_suite("res://tests/unit/diagnostics_log_test.gd")


func test_command_registry() -> void:
	_run_suite("res://tests/unit/command_registry_test.gd")


func test_led_blink_e2e() -> void:
	_run_suite("res://tests/integration/led_blink_e2e_test.gd")


func test_cli_stdin() -> void:
	_run_suite("res://tests/integration/cli_stdin_test.gd")
