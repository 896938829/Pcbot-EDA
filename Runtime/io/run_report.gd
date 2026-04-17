class_name RunReport
extends RefCounted

## 覆盖写 .pcbot/last-run.json + .pcbot/commit-msg。

const SCHEMA_VERSION: int = 1


static func write(project_root: String, command: String, params: Dictionary, result: Result) -> Error:
	if project_root == "":
		return ERR_INVALID_PARAMETER
	var pcbot_dir := ProjectFs.pcbot_dir(project_root)
	var mk := ProjectFs.ensure_dir(pcbot_dir)
	if mk != OK:
		return mk

	var record := {
		"schema_version": SCHEMA_VERSION,
		"ts": Time.get_datetime_string_from_system(true),
		"command": command,
		"params": params,
		"exit_code": PcbotError.code_to_exit(result.code),
		"ok": result.ok,
		"errors": result.errors,
		"warnings": result.warnings,
		"touched_files": _sorted_unique(result.touched_files),
	}

	var last_run_path := pcbot_dir.path_join("last-run.json")
	var we := JsonStable.write_file(last_run_path, record)
	if we != OK:
		return we

	if result.ok and not result.touched_files.is_empty():
		var msg := _build_commit_msg(command, params, result)
		var cmp := pcbot_dir.path_join("commit-msg")
		var f := FileAccess.open(cmp, FileAccess.WRITE)
		if f != null:
			f.store_string(msg)
			f.close()

	return OK


static func _build_commit_msg(command: String, params: Dictionary, result: Result) -> String:
	var parts := command.split(".")
	var scope: String = parts[0] if parts.size() > 0 else "cli"
	var summary := "%s: %s" % [scope, command]
	var body := ""
	if not result.touched_files.is_empty():
		body += "touched:\n"
		var sf: Array = _sorted_unique(result.touched_files)
		for p in sf:
			body += "- %s\n" % p
	body += "\nparams: %s\n" % JSON.stringify(params)
	return "%s\n\n%s" % [summary, body]


static func _sorted_unique(arr: Array) -> Array:
	var seen: Dictionary = {}
	for a in arr:
		seen[a] = true
	var keys: Array = seen.keys()
	keys.sort()
	return keys
