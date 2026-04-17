class_name LibraryCommands
extends RefCounted

## library.list / library.add_symbol / library.add_component / library.search


static func register(registry: CommandRegistry) -> void:
	registry.add("library.list", func(p): return _list(p))
	registry.add("library.add_symbol", func(p): return _add_symbol(p))
	registry.add("library.add_component", func(p): return _add_component(p))
	registry.add("library.search", func(p): return _search(p))


static func _resolve_lib_root(params: Dictionary) -> String:
	var lib_root: String = str(params.get("lib_root", ""))
	if lib_root != "":
		return ProjectFs.normalize(lib_root)
	var project_path: String = str(params.get("project", ""))
	if project_path != "":
		return ProjectFs.normalize(project_path.get_base_dir().path_join("library"))
	return ""


static func _list(params: Dictionary) -> Result:
	var root := _resolve_lib_root(params)
	if root == "":
		return Result.err(1, "missing 'lib_root' or 'project'")
	var idx := LibraryIndex.new()
	idx.load_from_root(root)
	return Result.success({
		"lib_root": root,
		"symbols": idx.list_symbols(),
		"components": idx.list_components(),
	})


static func _add_symbol(params: Dictionary) -> Result:
	var root := _resolve_lib_root(params)
	var id: String = str(params.get("id", ""))
	if root == "" or id == "":
		return Result.err(1, "missing 'lib_root' and/or 'id'")
	var rel_path: String = str(params.get("rel_path", "symbols/%s.sym.json" % id))
	var full := root.path_join(rel_path)
	ProjectFs.ensure_dir(full.get_base_dir())
	var sym := ComponentSymbol.new()
	sym.id = id
	sym.name = str(params.get("name", id))
	sym.pins = params.get("pins", [])
	sym.graphic_svg_ref = str(params.get("graphic_svg_ref", ""))
	sym.bbox_nm = params.get("bbox_nm", [0, 0, 0, 0])
	sym.metadata = params.get("metadata", {})
	var we := JsonStable.write_file(full, sym.to_dict())
	if we != OK:
		return Result.err(2, "write failed: %d" % we)
	var r := Result.success({"path": full, "id": id})
	r.add_touched(full)
	return r


static func _add_component(params: Dictionary) -> Result:
	var root := _resolve_lib_root(params)
	var id: String = str(params.get("id", ""))
	if root == "" or id == "":
		return Result.err(1, "missing 'lib_root' and/or 'id'")
	var rel_path: String = str(params.get("rel_path", "components/%s.comp.json" % id))
	var full := root.path_join(rel_path)
	ProjectFs.ensure_dir(full.get_base_dir())
	var c := LibraryComponent.new()
	c.id = id
	c.manufacturer = str(params.get("manufacturer", ""))
	c.part_number = str(params.get("part_number", ""))
	c.description = str(params.get("description", ""))
	c.symbol_ref = str(params.get("symbol_ref", ""))
	c.footprint_refs = params.get("footprint_refs", [])
	c.parameters = params.get("parameters", {})
	c.tags = params.get("tags", [])
	var we := JsonStable.write_file(full, c.to_dict())
	if we != OK:
		return Result.err(2, "write failed: %d" % we)
	var r := Result.success({"path": full, "id": id})
	r.add_touched(full)
	return r


static func _search(params: Dictionary) -> Result:
	var root := _resolve_lib_root(params)
	if root == "":
		return Result.err(1, "missing 'lib_root' or 'project'")
	var query: String = str(params.get("query", ""))
	var field: String = str(params.get("field", ""))
	var idx := LibraryIndex.new()
	idx.load_from_root(root)
	var hits := idx.search(query, field)
	return Result.success({"query": query, "count": hits.size(), "results": hits})
