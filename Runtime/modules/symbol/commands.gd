class_name SymbolCommands
extends RefCounted

## symbol.create / symbol.edit_pin / symbol.export_svg


static func register(registry: CommandRegistry) -> void:
	registry.add("symbol.create", func(p): return _create(p))
	registry.add("symbol.edit_pin", func(p): return _edit_pin(p))
	registry.add("symbol.export_svg", func(p): return _export_svg(p))


static func _create(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	if path == "":
		return Result.err(1, "missing 'path'")
	var sym := ComponentSymbol.new()
	sym.id = str(params.get("id", path.get_file().get_basename()))
	sym.name = str(params.get("name", sym.id))
	sym.pins = params.get("pins", [])
	sym.graphic_svg_ref = str(params.get("graphic_svg_ref", ""))
	sym.bbox_nm = params.get("bbox_nm", [0, 0, 0, 0])
	sym.metadata = params.get("metadata", {})
	var we := JsonStable.write_file(path, sym.to_dict())
	if we != OK:
		return Result.err(2, "write failed: %d" % we)
	var r := Result.success({"path": path, "id": sym.id})
	r.add_touched(path)
	return r


static func _edit_pin(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var number: String = str(params.get("number", ""))
	if path == "" or number == "":
		return Result.err(1, "missing 'path' or 'number'")
	var data = JsonStable.read_file(path)
	if data == null:
		return Result.err(1, "symbol not found: %s" % path)
	var sym := ComponentSymbol.from_dict(data)
	var found := false
	for p in sym.pins:
		if str(p.get("number", "")) == number:
			if params.has("name"): p["name"] = params["name"]
			if params.has("pos"): p["pos"] = params["pos"]
			if params.has("dir"): p["dir"] = params["dir"]
			found = true
			break
	if not found:
		var new_pin := {
			"number": number,
			"name": str(params.get("name", number)),
			"pos": params.get("pos", [0, 0]),
			"dir": str(params.get("dir", "right")),
		}
		sym.pins.append(new_pin)
	var we := JsonStable.write_file(path, sym.to_dict())
	if we != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "number": number, "updated": found})
	r.add_touched(path)
	return r


static func _export_svg(params: Dictionary) -> Result:
	var sym_path: String = str(params.get("path", ""))
	var svg_path: String = str(params.get("svg_path", ""))
	if sym_path == "" or svg_path == "":
		return Result.err(1, "missing 'path' or 'svg_path'")
	var data = JsonStable.read_file(sym_path)
	if data == null:
		return Result.err(1, "symbol not found")
	var sym := ComponentSymbol.from_dict(data)
	var vb_mm: Array = params.get("viewbox_mm", [0.0, 0.0, 20.0, 20.0])
	var shapes: Array = [
		{"type": "rect", "x": 2, "y": 2, "w": 16, "h": 16, "stroke": "black", "stroke_width": 0.2, "fill": "none"},
		{"type": "text", "x": 10, "y": 10, "font_size": 1.5, "text": sym.name},
	]
	for p in sym.pins:
		var pos: Array = p.get("pos", [0, 0])
		var x: float = UnitSystem.nm_to_mm(int(pos[0]))
		var y: float = UnitSystem.nm_to_mm(int(pos[1]))
		shapes.append({"type": "circle", "cx": x, "cy": y, "r": 0.4, "stroke": "black", "stroke_width": 0.15})
	var we := SvgIO.write_symbol(svg_path, vb_mm, shapes)
	if we != OK:
		return Result.err(2, "svg write failed")
	var r := Result.success({"svg_path": svg_path, "pin_count": sym.pins.size()})
	r.add_touched(svg_path)
	return r
