class_name CliStdinTest
extends RefCounted

## P4：通过 OS.execute 启 godot --headless -s cli/main.gd 子进程，验证：
## - 退出码与 PcbotError.code_to_exit 对齐
## - stdout 是合法 JSON-RPC 响应
## - --input <file> 旗标可绕开 stdin 阻塞


static func _run_cli(req_text: String, project_root: String) -> Dictionary:
	## 写临时 req 文件，执行子进程，回收 stdout/exit_code。
	var ts := str(Time.get_ticks_usec())
	var req_path := "user://cli_test_req_%s.json" % ts
	var f := FileAccess.open(req_path, FileAccess.WRITE)
	f.store_string(req_text)
	f.close()
	var req_abs := ProjectSettings.globalize_path(req_path)

	var godot := OS.get_executable_path()
	var args := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"-s",
		"cli/main.gd",
		"--",
		"--input",
		req_abs,
	])
	var out: Array = []
	var exit_code := OS.execute(godot, args, out, false, false)
	DirAccess.remove_absolute(req_abs)
	return {
		"exit_code": exit_code,
		"stdout": "" if out.is_empty() else str(out[0]),
	}


static func _last_json_line(blob: String) -> Dictionary:
	for line in blob.split("\n", false):
		var t := str(line).strip_edges()
		if t.begins_with("{") and t.ends_with("}"):
			var parsed = JSON.parse_string(t)
			if parsed is Dictionary:
				return parsed
	return {}


static func run() -> Array:
	var r: Array = []

	r.append(Assert.case("project_new_success", func():
		var proj := "user://cli_test_proj_%s.pcbproj" % Time.get_ticks_usec()
		var proj_abs := ProjectSettings.globalize_path(proj)
		var req := JSON.stringify({
			"jsonrpc": "2.0",
			"id": 1,
			"method": "project.new",
			"params": {"path": proj_abs},
		})
		var out := _run_cli(req, proj_abs.get_base_dir())
		if out["exit_code"] != 0:
			return "exit %d, stdout=%s" % [out["exit_code"], out["stdout"]]
		var resp := _last_json_line(out["stdout"])
		if resp.is_empty():
			return "no JSON response: %s" % out["stdout"]
		if not resp.has("result"):
			return "no result field: %s" % resp
		DirAccess.remove_absolute(proj_abs)
		return ""))

	r.append(Assert.case("invalid_method_returns_method_not_found", func():
		var req := JSON.stringify({
			"jsonrpc": "2.0",
			"id": 2,
			"method": "no.such.method",
			"params": {},
		})
		var out := _run_cli(req, "")
		if out["exit_code"] == 0:
			return "expected nonzero exit, got 0"
		var resp := _last_json_line(out["stdout"])
		if resp.is_empty():
			return "no JSON response: %s" % out["stdout"]
		var err: Dictionary = resp.get("error", {})
		if int(err.get("code", 0)) != JsonRpc.ErrorCode.METHOD_NOT_FOUND:
			return "code=%s expected %d" % [err.get("code"), JsonRpc.ErrorCode.METHOD_NOT_FOUND]
		return ""))

	r.append(Assert.case("parse_error_exits_nonzero", func():
		var out := _run_cli("not a json", "")
		if out["exit_code"] == 0:
			return "expected nonzero exit, got 0"
		var resp := _last_json_line(out["stdout"])
		if resp.is_empty():
			return "no JSON response: %s" % out["stdout"]
		var err: Dictionary = resp.get("error", {})
		if int(err.get("code", 0)) != JsonRpc.ErrorCode.PARSE_ERROR:
			return "code=%s expected %d" % [err.get("code"), JsonRpc.ErrorCode.PARSE_ERROR]
		return ""))

	return r
