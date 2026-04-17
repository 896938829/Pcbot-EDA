class_name ProjectCommands
extends RefCounted

## project.new / project.open / project.info


static func register(registry: CommandRegistry) -> void:
	registry.add("project.new", func(p): return _new(p))
	registry.add("project.open", func(p): return _open(p))
	registry.add("project.info", func(p): return _info(p))


static func _new(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var name: String = str(params.get("name", ""))
	if path == "":
		return Result.err(1, "missing 'path'")
	path = ProjectFs.normalize(path)
	var dir := path.get_base_dir()
	if dir != "":
		ProjectFs.ensure_dir(dir)
	var project := DesignProject.new()
	project.name = name if name != "" else path.get_file().get_basename()
	project.settings = {"created_at": Time.get_datetime_string_from_system(true)}
	var we := JsonStable.write_file(path, project.to_dict())
	if we != OK:
		return Result.err(2, "failed to write project: %d" % we)
	var root := path.get_base_dir()
	ProjectFs.ensure_pcbot(root)
	var r := Result.success({
		"path": path,
		"name": project.name,
		"project_root": root,
	})
	r.add_touched(path)
	return r


static func _open(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	if path == "":
		return Result.err(1, "missing 'path'")
	path = ProjectFs.normalize(path)
	var data = JsonStable.read_file(path)
	if data == null:
		return Result.err(1, "project not found or invalid: %s" % path)
	var p := DesignProject.from_dict(data)
	return Result.success({
		"path": path,
		"name": p.name,
		"schematic_refs": p.schematic_refs,
		"library_refs": p.library_refs,
		"project_root": path.get_base_dir(),
	})


static func _info(params: Dictionary) -> Result:
	return _open(params)
