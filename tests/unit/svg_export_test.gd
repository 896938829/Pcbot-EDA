class_name SvgExportTest
extends RefCounted

## P3：SvgIO.render_symbol 输出真符号几何（外形 + 引脚 + 方向 + 名称）。


static func _make_ne555() -> ComponentSymbol:
	var sym := ComponentSymbol.new()
	sym.id = "NE555"
	sym.name = "NE555"
	sym.bbox_nm = [0, 0, 20_000_000, 30_000_000]  ## 20mm x 30mm
	for i in 8:
		var dir := "left" if i < 4 else "right"
		sym.pins.append({
			"number": str(i + 1),
			"name": "P%d" % (i + 1),
			"pos": [0 if dir == "left" else 20_000_000, (i % 4 + 1) * 5_000_000],
			"dir": dir,
		})
	return sym


static func _count_type(shapes: Array, type_name: String) -> int:
	var n := 0
	for s in shapes:
		if str(s.get("type", "")) == type_name:
			n += 1
	return n


static func run() -> Array:
	var r: Array = []

	r.append(Assert.case("ne555_has_correct_pin_count", func():
		var rendered := SvgIO.render_symbol(_make_ne555())
		var shapes: Array = rendered["shapes"]
		## 每个 pin 产 1 line + 1 circle (+ 可选 text)
		var circles := _count_type(shapes, "circle")
		if circles < 8:
			return "expected ≥8 pin circles, got %d" % circles
		var lines := _count_type(shapes, "line")
		if lines < 8:
			return "expected ≥8 pin direction lines, got %d" % lines
		return ""))

	r.append(Assert.case("viewbox_from_bbox_in_mm", func():
		var sym := ComponentSymbol.new()
		sym.bbox_nm = [0, 0, 20_000_000, 10_000_000]
		var rendered := SvgIO.render_symbol(sym)
		var vb: Array = rendered["viewbox"]
		## bbox 20x10 mm + 2mm pad → vb [-2, -2, 24, 14]
		if abs(float(vb[0]) - (-2.0)) > 0.01 or abs(float(vb[2]) - 24.0) > 0.01:
			return "vb=%s expected [-2,-2,24,14]" % str(vb)
		return ""))

	r.append(Assert.case("missing_outline_falls_back_to_rect", func():
		var sym := ComponentSymbol.new()
		sym.bbox_nm = [0, 0, 10_000_000, 10_000_000]
		var rendered := SvgIO.render_symbol(sym)
		var shapes: Array = rendered["shapes"]
		var rects := _count_type(shapes, "rect")
		if rects < 1:
			return "expected outline rect, got %d rects" % rects
		return ""))

	r.append(Assert.case("bbox_from_pins_when_all_zero", func():
		var sym := ComponentSymbol.new()
		sym.bbox_nm = [0, 0, 0, 0]
		sym.pins = [
			{"number": "1", "name": "A", "pos": [0, 0], "dir": "left"},
			{"number": "2", "name": "B", "pos": [10_000_000, 5_000_000], "dir": "right"},
		]
		var rendered := SvgIO.render_symbol(sym)
		var vb: Array = rendered["viewbox"]
		## pins span 0..10 mm x 0..5 mm → +2mm pad → [-2, -2, 14, 9]
		if abs(float(vb[0]) - (-2.0)) > 0.01 or abs(float(vb[1]) - (-2.0)) > 0.01:
			return "vb=%s expected origin [-2,-2]" % str(vb)
		if abs(float(vb[2]) - 14.0) > 0.01 or abs(float(vb[3]) - 9.0) > 0.01:
			return "vb=%s expected size [14,9]" % str(vb)
		return ""))

	r.append(Assert.case("polygon_outline_when_metadata_set", func():
		var sym := ComponentSymbol.new()
		sym.bbox_nm = [0, 0, 10_000_000, 10_000_000]
		sym.metadata = {
			"outline_shape": "polygon",
			"outline_points_mm": [[0, 0], [10, 0], [5, 10]],
		}
		var rendered := SvgIO.render_symbol(sym)
		var shapes: Array = rendered["shapes"]
		var polys := _count_type(shapes, "polygon")
		if polys != 1:
			return "expected 1 polygon, got %d" % polys
		return ""))

	r.append(Assert.case("end_to_end_write_svg", func():
		var sym_path := "user://svg_e2e.sym.json"
		var svg_path := "user://svg_e2e.sym.svg"
		var sym := _make_ne555()
		JsonStable.write_file(sym_path, sym.to_dict())
		var res := SymbolCommands._export_svg({"path": sym_path, "svg_path": svg_path})
		if not res.ok:
			return "export err: %s" % res.error
		if not FileAccess.file_exists(svg_path):
			return "svg not written"
		var f := FileAccess.open(svg_path, FileAccess.READ)
		var blob := f.get_as_text()
		f.close()
		if not blob.contains("viewBox=") or not blob.contains("<line"):
			return "svg missing expected markup"
		return ""))

	return r
