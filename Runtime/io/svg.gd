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


## 写最小符号 SVG：仅包含 viewBox + 已命名的图元（线、圆、矩形、文本）。
## shapes: [{type:"line"/"rect"/"circle"/"text", ...}]
static func write_symbol(path: String, viewbox_mm: Array, shapes: Array) -> Error:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var vb := "%s %s %s %s" % [str(viewbox_mm[0]), str(viewbox_mm[1]), str(viewbox_mm[2]), str(viewbox_mm[3])]
	var out := "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	out += "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"%s\">\n" % vb
	for s in shapes:
		out += "  " + _shape(s) + "\n"
	out += "</svg>\n"
	f.store_string(out)
	f.close()
	return OK


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
			return "<text x=\"%s\" y=\"%s\" font-size=\"%s\">%s</text>" % [
				str(s.get("x", 0)), str(s.get("y", 0)), str(s.get("font_size", 1.2)),
				str(s.get("text", "")),
			]
		_:
			return "<!-- unknown shape -->"
