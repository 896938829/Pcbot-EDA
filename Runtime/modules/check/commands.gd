class_name CheckCommands
extends RefCounted

## check.basic —— 基础自检（未连接的引脚、悬空网络、未放置元件）。
## 违例记录追加到 .pcbot/diagnostics.jsonl。


static func register(registry: CommandRegistry) -> void:
	registry.add("check.basic", func(p): return _basic(p))


static func _basic(params: Dictionary) -> Result:
	var schematic_path: String = str(params.get("schematic", ""))
	if schematic_path == "":
		return Result.err(1, "missing 'schematic'")
	var data = JsonStable.read_file(schematic_path)
	if data == null:
		return Result.err(1, "schematic not found")
	var s := Schematic.from_dict(data)
	var project_root: String = str(params.get("project_root", schematic_path.get_base_dir()))

	var violations: Array = []

	## Rule 1: 每张原理图至少一个放置
	if s.placements.is_empty():
		violations.append({"rule": "sch.empty", "ref": s.id, "sev": "error", "msg": "原理图没有任何元件"})

	## Rule 2: 每个放置至少要在某个网络里被引用一次（宽松：多于 1 管脚的元件）
	var pin_to_nets: Dictionary = {}
	for n in s.nets:
		for pin_ref in n.get("pins", []):
			pin_to_nets[str(pin_ref)] = pin_to_nets.get(str(pin_ref), 0) + 1

	for pl in s.placements:
		var ref: String = str(pl.get("reference", ""))
		var found := false
		for key in pin_to_nets.keys():
			if (key as String).begins_with(ref + "."):
				found = true
				break
		if not found:
			violations.append({
				"rule": "placement.unconnected",
				"ref": ref,
				"sev": "warn",
				"msg": "元件 %s 未连入任何网络" % ref,
			})

	## Rule 3: 每个网络至少 2 个引脚
	for n in s.nets:
		var pins: Array = n.get("pins", [])
		if pins.size() < 2:
			violations.append({
				"rule": "net.floating",
				"ref": str(n.get("id", "")),
				"sev": "error",
				"msg": "网络 %s 少于 2 个引脚（%d）" % [n.get("name", ""), pins.size()],
			})

	var resolved_count := 0
	var new_violation_count := 0
	var current_keys: Dictionary = {}
	for v in violations:
		var k: String = "%s|%s" % [v["rule"], v["ref"]]
		current_keys[k] = true
		var added := DiagnosticsLog.record_violation(project_root, v["rule"], v["sev"], v["ref"], v["msg"])
		if added:
			new_violation_count += 1

	## 消除：之前未解决但本次未复现的，打 resolved
	var prev := DiagnosticsLog.list_unresolved(project_root)
	var commit_sha := _get_head_sha(project_root)
	for r in prev:
		var k := "%s|%s" % [str(r.get("rule_id", "")), str(r.get("ref", ""))]
		if not current_keys.has(k):
			if DiagnosticsLog.mark_resolved(project_root, str(r.get("rule_id", "")), str(r.get("ref", "")), commit_sha):
				resolved_count += 1

	var has_error := false
	for v in violations:
		if v["sev"] == "error":
			has_error = true
			break

	var r := Result.new()
	r.data = {
		"schematic": schematic_path,
		"violations": violations,
		"new_recorded": new_violation_count,
		"newly_resolved": resolved_count,
	}
	r.touched_files.append(DiagnosticsLog.path(project_root))
	if has_error:
		r.ok = false
		r.code = 3
		r.message = "有规则违例"
		for v in violations:
			if v["sev"] == "error":
				r.errors.append({"code": "RULE_VIOLATION", "rule": v["rule"], "ref": v["ref"], "msg": v["msg"]})
	else:
		r.ok = true
		r.code = 0
		for v in violations:
			if v["sev"] == "warn":
				r.add_warning(v["rule"], v["ref"], v["msg"])
	return r


static func _get_head_sha(project_root: String) -> String:
	var head_path := project_root.path_join(".git/HEAD")
	if not FileAccess.file_exists(head_path):
		return "unknown"
	var f := FileAccess.open(head_path, FileAccess.READ)
	if f == null:
		return "unknown"
	var head := f.get_as_text().strip_edges()
	f.close()
	if head.begins_with("ref: "):
		var ref := head.substr(5).strip_edges()
		var ref_path := project_root.path_join(".git").path_join(ref)
		if FileAccess.file_exists(ref_path):
			var rf := FileAccess.open(ref_path, FileAccess.READ)
			if rf != null:
				var sha := rf.get_as_text().strip_edges()
				rf.close()
				return sha
	return head
