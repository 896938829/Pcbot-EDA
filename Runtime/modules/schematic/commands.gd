class_name SchematicCommands
extends RefCounted

## schematic.new / add_page / place_component / connect / annotate


static func register(registry: CommandRegistry) -> void:
	registry.add("schematic.new", func(p): return _new(p))
	registry.add("schematic.add_page", func(p): return _add_page(p))
	registry.add("schematic.place_component", func(p): return _place_component(p))
	registry.add("schematic.connect", func(p): return _connect(p))
	registry.add("schematic.annotate", func(p): return _annotate(p))


static func _load(path: String) -> Schematic:
	var data = JsonStable.read_file(path)
	if data == null:
		return null
	return Schematic.from_dict(data)


static func _save(path: String, s: Schematic) -> int:
	return JsonStable.write_file(path, s.to_dict())


static func _new(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	if path == "":
		return Result.err(1, "missing 'path'")
	var s := Schematic.new()
	s.id = str(params.get("id", path.get_file().get_basename()))
	s.pages = [{
		"id": "p1",
		"name": "Main",
		"size_nm": [UnitSystem.mm_to_nm(297.0), UnitSystem.mm_to_nm(210.0)],
	}]
	var we := _save(path, s)
	if we != OK:
		return Result.err(2, "write failed: %d" % we)
	var r := Result.success({"path": path, "id": s.id})
	r.add_touched(path)
	return r


static func _add_page(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var page_id: String = str(params.get("page_id", ""))
	if path == "" or page_id == "":
		return Result.err(1, "missing 'path' or 'page_id'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	if not s.find_page(page_id).is_empty():
		return Result.err(1, "page already exists: %s" % page_id)
	s.pages.append({
		"id": page_id,
		"name": str(params.get("name", page_id)),
		"size_nm": params.get("size_nm", [UnitSystem.mm_to_nm(297.0), UnitSystem.mm_to_nm(210.0)]),
	})
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "page_id": page_id})
	r.add_touched(path)
	return r


static func _place_component(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var page_id: String = str(params.get("page_id", "p1"))
	var component_ref: String = str(params.get("component_ref", ""))
	var reference: String = str(params.get("reference", ""))
	var pos_nm: Array = params.get("pos_nm", [0, 0])
	if path == "" or component_ref == "" or reference == "":
		return Result.err(1, "missing 'path', 'component_ref' or 'reference'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	if s.find_page(page_id).is_empty():
		return Result.err(1, "page not found: %s" % page_id)
	if not s.find_placement_by_ref(reference).is_empty():
		return Result.err(1, "reference already used: %s" % reference)
	var pl := SchPlacement.new()
	pl.uid = s.next_placement_uid()
	pl.page_id = page_id
	pl.component_ref = component_ref
	pl.reference = reference
	pl.pos_nm = pos_nm
	pl.rotation_deg = int(params.get("rotation_deg", 0))
	pl.mirror = bool(params.get("mirror", false))
	s.placements.append(pl.to_dict())
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "uid": pl.uid, "reference": reference})
	r.add_touched(path)
	return r


static func _connect(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var net_name: String = str(params.get("net", ""))
	var pins: Array = params.get("pins", [])
	if path == "" or pins.is_empty():
		return Result.err(1, "missing 'path' or 'pins'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	for pin_ref in pins:
		var parts := str(pin_ref).split(".")
		if parts.size() != 2:
			return Result.err(1, "invalid pin ref: %s (expect 'REF.pin')" % pin_ref)
		if s.find_placement_by_ref(parts[0]).is_empty():
			return Result.err(1, "unknown placement: %s" % parts[0])

	var net_dict: Dictionary = {}
	if net_name != "":
		net_dict = s.find_net_by_name(net_name)
	var is_new := net_dict.is_empty()
	if is_new:
		var n := SchNet.new()
		n.id = s.next_net_id()
		n.name = net_name if net_name != "" else n.id
		n.pins = []
		for p in pins:
			if not n.pins.has(str(p)):
				n.pins.append(str(p))
		s.nets.append(n.to_dict())
	else:
		var existing_pins: Array = net_dict.get("pins", [])
		for p in pins:
			if not existing_pins.has(str(p)):
				existing_pins.append(str(p))
		net_dict["pins"] = existing_pins

	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "net": net_name, "pin_count": pins.size()})
	r.add_touched(path)
	return r


static func _annotate(params: Dictionary) -> Result:
	## 自动重新编号未命名元件。M1 简化版：按放置顺序为 "?" 结尾的 reference 赋号。
	var path: String = str(params.get("path", ""))
	if path == "":
		return Result.err(1, "missing 'path'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	var counters: Dictionary = {}
	## 先扫已命名的，用其最大编号初始化 counter
	for pl in s.placements:
		var ref: String = str(pl.get("reference", ""))
		if ref.ends_with("?") or ref == "":
			continue
		var prefix := ""
		var num := 0
		for i in ref.length():
			if ref[i].is_valid_int():
				prefix = ref.substr(0, i)
				num = int(ref.substr(i))
				break
		if prefix != "":
			counters[prefix] = max(counters.get(prefix, 0), num)

	var renamed := 0
	for pl in s.placements:
		var ref: String = str(pl.get("reference", ""))
		if ref.ends_with("?"):
			var prefix := ref.substr(0, ref.length() - 1)
			var next_n: int = int(counters.get(prefix, 0)) + 1
			counters[prefix] = next_n
			pl["reference"] = "%s%d" % [prefix, next_n]
			renamed += 1
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "renamed": renamed})
	r.add_touched(path)
	return r
