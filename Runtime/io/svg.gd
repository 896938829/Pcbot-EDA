class_name SvgIO
extends RefCounted

## M1 最小 SVG：读 viewBox + 写最简符号 SVG。
## 不支持复杂 SVG 变换 / 滤镜 / 动画。

static func read_viewbox(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	var idx := text.find("viewBox=\"")
	if idx < 0:
		return []
	var start := idx + "viewBox=\"".length()
	var end := text.find("\"", start)
	if end < 0:
		return []
	var parts := text.substr(start, end - start).strip_edges().split(" ", false)
	if parts.size() < 4:
		return []
	return [float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])]


## 写最小符号 SVG：仅包含 viewBox + 已命名的图元（线、圆、矩形、文本、polygon、path）。
## shapes: [{type:"line"/"rect"/"circle"/"text"/"polygon"/"path", ...}]
static func write_symbol(path: String, viewbox_mm: Array, shapes: Array) -> Error:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(svg_to_string(viewbox_mm, shapes))
	f.close()
	return OK


## 同 write_symbol，但返回 SVG 字符串（供 UI 直接 load_svg_from_buffer 使用，免落盘）。
static func svg_to_string(viewbox_mm: Array, shapes: Array) -> String:
	var vb := "%s %s %s %s" % [str(viewbox_mm[0]), str(viewbox_mm[1]), str(viewbox_mm[2]), str(viewbox_mm[3])]
	var out := "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	out += "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"%s\">\n" % vb
	for s in shapes:
		out += "  " + _shape(s) + "\n"
	out += "</svg>\n"
	return out


static func _shape(s: Dictionary) -> String:
	match str(s.get("type", "")):
		"line":
			return "<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"%s\" />" % [
				str(s.get("x1", 0)), str(s.get("y1", 0)),
				str(s.get("x2", 0)), str(s.get("y2", 0)),
				str(s.get("stroke", "black")), str(s.get("stroke_width", 0.15)),
			]
		"rect":
			return "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" />" % [
				str(s.get("x", 0)), str(s.get("y", 0)),
				str(s.get("w", 0)), str(s.get("h", 0)),
				str(s.get("fill", "none")), str(s.get("stroke", "black")), str(s.get("stroke_width", 0.15)),
			]
		"circle":
			return "<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" />" % [
				str(s.get("cx", 0)), str(s.get("cy", 0)), str(s.get("r", 1)),
				str(s.get("fill", "none")), str(s.get("stroke", "black")), str(s.get("stroke_width", 0.15)),
			]
		"text":
			return "<text x=\"%s\" y=\"%s\" font-size=\"%s\" text-anchor=\"%s\">%s</text>" % [
				str(s.get("x", 0)), str(s.get("y", 0)), str(s.get("font_size", 1.2)),
				str(s.get("anchor", "start")), str(s.get("text", "")),
			]
		"polygon":
			var pts: Array = s.get("points", [])
			var pts_str := PackedStringArray()
			for pt in pts:
				pts_str.append("%s,%s" % [str(pt[0]), str(pt[1])])
			return "<polygon points=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" />" % [
				" ".join(pts_str),
				str(s.get("fill", "none")), str(s.get("stroke", "black")), str(s.get("stroke_width", 0.15)),
			]
		"path":
			return "<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" />" % [
				str(s.get("d", "")),
				str(s.get("fill", "none")), str(s.get("stroke", "black")), str(s.get("stroke_width", 0.15)),
			]
		_:
			return "<!-- unknown shape -->"


## 从 ComponentSymbol 渲染完整符号 SVG 数据。
## 返回 {viewbox: [x, y, w, h], shapes: [...]}，单位 mm。
## 外形优先级：metadata.outline_shape == "circle" → 圆；"polygon" + outline_points_mm → 多边形；
##             否则按 bbox_nm 画矩形。
## 引脚：圆点 + 引脚编号文本（外侧）+ 方向短线（按 dir）；name 不为空时绘内侧文本。
static func render_symbol(sym: ComponentSymbol) -> Dictionary:
	var bbox: Array = sym.bbox_nm if sym.bbox_nm.size() == 4 else [0, 0, 0, 0]
	var x0_mm := UnitSystem.nm_to_mm(int(bbox[0]))
	var y0_mm := UnitSystem.nm_to_mm(int(bbox[1]))
	var x1_mm := UnitSystem.nm_to_mm(int(bbox[2]))
	var y1_mm := UnitSystem.nm_to_mm(int(bbox[3]))
	var pad: float = 2.0  ## 留 2mm 给引脚伸出与编号
	var vb := [x0_mm - pad, y0_mm - pad, (x1_mm - x0_mm) + 2 * pad, (y1_mm - y0_mm) + 2 * pad]

	var shapes: Array = []
	var outline := str(sym.metadata.get("outline_shape", "rect"))
	if outline == "circle":
		var cx: float = (x0_mm + x1_mm) * 0.5
		var cy: float = (y0_mm + y1_mm) * 0.5
		var r: float = max(x1_mm - x0_mm, y1_mm - y0_mm) * 0.5
		shapes.append({"type": "circle", "cx": cx, "cy": cy, "r": r, "stroke": "black", "stroke_width": 0.2})
	elif outline == "polygon" and sym.metadata.has("outline_points_mm"):
		shapes.append({
			"type": "polygon",
			"points": sym.metadata["outline_points_mm"],
			"stroke": "black",
			"stroke_width": 0.2,
		})
	else:
		shapes.append({
			"type": "rect",
			"x": x0_mm, "y": y0_mm, "w": x1_mm - x0_mm, "h": y1_mm - y0_mm,
			"stroke": "black", "stroke_width": 0.2,
		})

	for p in sym.pins:
		var pos: Array = p.get("pos", [0, 0])
		var px: float = UnitSystem.nm_to_mm(int(pos[0]))
		var py: float = UnitSystem.nm_to_mm(int(pos[1]))
		var dir: String = str(p.get("dir", "right"))
		var stub: float = 1.5  ## mm
		var dx: float = 0.0
		var dy: float = 0.0
		match dir:
			"left": dx = -stub
			"right": dx = stub
			"up": dy = -stub
			"down": dy = stub
		shapes.append({"type": "line", "x1": px, "y1": py, "x2": px + dx, "y2": py + dy, "stroke_width": 0.2})
		shapes.append({"type": "circle", "cx": px + dx, "cy": py + dy, "r": 0.3, "stroke_width": 0.15, "fill": "white"})
		var num_text: String = str(p.get("number", ""))
		if num_text != "":
			shapes.append({
				"type": "text",
				"x": px + dx * 1.4, "y": py + dy * 1.4 + 0.4,
				"font_size": 1.0, "text": num_text, "anchor": "middle",
			})
		var name_text: String = str(p.get("name", ""))
		if name_text != "" and name_text != num_text:
			shapes.append({
				"type": "text",
				"x": px - dx * 0.5, "y": py - dy * 0.5 + 0.3,
				"font_size": 0.8, "text": name_text, "anchor": "middle",
			})

	if sym.name != "":
		shapes.append({
			"type": "text",
			"x": (x0_mm + x1_mm) * 0.5, "y": y0_mm - 0.5,
			"font_size": 1.2, "text": sym.name, "anchor": "middle",
		})

	return {"viewbox": vb, "shapes": shapes}
