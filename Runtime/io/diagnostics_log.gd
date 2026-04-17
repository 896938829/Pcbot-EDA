class_name DiagnosticsLog
extends RefCounted

## .pcbot/diagnostics.jsonl：追加写；按 {rule_id, ref} 去重；消除违例走 resolved_by_commit 追加。

const SCHEMA_VERSION: int = 1


static func path(project_root: String) -> String:
	return ProjectFs.pcbot_dir(project_root).path_join("diagnostics.jsonl")


static func record_violation(project_root: String, rule_id: String, severity: String, ref: String, msg: String) -> bool:
	## 若当前未解决集已含该 {rule_id, ref}，则跳过（幂等）。返回是否实际写入。
	var p := path(project_root)
	var existing := _unresolved(p)
	var key := "%s|%s" % [rule_id, ref]
	if existing.has(key):
		return false
	var record := {
		"schema_version": SCHEMA_VERSION,
		"ts": Time.get_datetime_string_from_system(true),
		"rule_id": rule_id,
		"severity": severity,
		"ref": ref,
		"msg": msg,
		"resolved_by_commit": null,
	}
	ProjectFs.ensure_dir(p.get_base_dir())
	Jsonl.append(p, record)
	return true


static func mark_resolved(project_root: String, rule_id: String, ref: String, commit_sha: String) -> bool:
	## 仅当当前确有未解决记录时才追加消除记录。
	var p := path(project_root)
	var existing := _unresolved(p)
	var key := "%s|%s" % [rule_id, ref]
	if not existing.has(key):
		return false
	var record := {
		"schema_version": SCHEMA_VERSION,
		"ts": Time.get_datetime_string_from_system(true),
		"rule_id": rule_id,
		"severity": "info",
		"ref": ref,
		"msg": "resolved",
		"resolved_by_commit": commit_sha,
	}
	Jsonl.append(p, record)
	return true


static func list_unresolved(project_root: String) -> Array:
	var p := path(project_root)
	var key_set := _unresolved(p)
	var records := Jsonl.read_all(p)
	var latest: Dictionary = {}
	for r in records:
		var k := "%s|%s" % [str(r.get("rule_id", "")), str(r.get("ref", ""))]
		if key_set.has(k) and r.get("resolved_by_commit", null) == null:
			latest[k] = r
	return latest.values()


static func _unresolved(p: String) -> Dictionary:
	## 遍历：违例记录加入，resolved 记录移除。最后剩下即未解决集。
	var out: Dictionary = {}
	if not FileAccess.file_exists(p):
		return out
	var records := Jsonl.read_all(p)
	for r in records:
		var k := "%s|%s" % [str(r.get("rule_id", "")), str(r.get("ref", ""))]
		if r.get("resolved_by_commit", null) == null:
			out[k] = true
		else:
			out.erase(k)
	return out
