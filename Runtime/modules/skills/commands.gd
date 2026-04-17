class_name SkillsCommands
extends RefCounted

## skills.list / skills.get


static func register(registry: CommandRegistry) -> void:
	registry.add("skills.list", func(p): return _list(p))
	registry.add("skills.get", func(p): return _get_skill(p))


static func _skills_root() -> String:
	return ProjectFs.normalize(ProjectSettings.globalize_path("res://docs/skills"))


static func _list(_params: Dictionary) -> Result:
	var root := _skills_root()
	var files := ProjectFs.walk_files(root, ".yaml")
	var names: Array = []
	for f in files:
		var stem: String = f.get_file().get_basename()
		var ns: String = f.get_base_dir().get_file()
		names.append({"name": "%s.%s" % [ns, stem], "path": f})
	names.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return Result.success({"count": names.size(), "skills": names})


static func _get_skill(params: Dictionary) -> Result:
	var name: String = str(params.get("name", ""))
	if name == "":
		return Result.err(1, "missing 'name'")
	var parts := name.split(".")
	if parts.size() != 2:
		return Result.err(1, "name must be '<namespace>.<method>'")
	var path := _skills_root().path_join(parts[0]).path_join("%s.yaml" % parts[1])
	if not FileAccess.file_exists(path):
		return Result.err(1, "skill not found: %s" % name)
	var y = YamlIO.read_file(path)
	return Result.success({"name": name, "path": path, "skill": y})
