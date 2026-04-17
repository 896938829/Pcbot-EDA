class_name RunCommands
extends RefCounted

## run.last —— 读 .pcbot/last-run.json。


static func register(registry: CommandRegistry) -> void:
	registry.add("run.last", func(p): return _last(p))


static func _last(params: Dictionary) -> Result:
	var project_root: String = str(params.get("project_root", ""))
	if project_root == "":
		return Result.err(1, "missing 'project_root'")
	var p := ProjectFs.pcbot_dir(project_root).path_join("last-run.json")
	if not FileAccess.file_exists(p):
		return Result.err(1, "no last-run.json at %s" % p)
	var data = JsonStable.read_file(p)
	if data == null:
		return Result.err(2, "invalid last-run.json")
	return Result.success({"path": p, "last_run": data})
