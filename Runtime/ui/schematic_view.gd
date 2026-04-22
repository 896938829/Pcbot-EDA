extends Control

## 原理图只读视图：符号（SVG 纹理优先，回退矩形）、网络连线（中心到中心直线近似）。
## M1.1：SVG 渲染走 SvgIO.render_symbol → ImageTexture 缓存。
## M1 不做 UI 编辑，所有编辑走 CLI。

const WORLD_PER_NM: float = 1.0 / 10000.0  ## 10000 nm = 1 world unit
const TEXTURE_ZOOM_THRESHOLD: float = 0.4  ## 缩放低于此阈值时回退矩形，避免百元件全纹理绘制卡顿

signal schematic_changed  ## disk 落盘后发出，供属性面板 / 状态栏刷新
signal selection_changed(kind: String, uid: String, data: Dictionary)  ## kind: "placement" or ""

var _schematic: Schematic
var _symbol_cache: Dictionary = {}      ## id → sym dict
var _texture_cache: Dictionary = {}     ## id → ImageTexture（无纹理则不入）
var _bbox_cache: Dictionary = {}        ## id → Rect2 in mm（用于纹理缩放定位）
var _lib_root: String = ""
var _sch_path: String = ""               ## 当前原理图文件路径（drop/编辑落盘用）
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _drag_active: bool = false
var _drag_last: Vector2
var _selected_uid: String = ""  ## 当前选中的 placement uid，""=无选中


func set_schematic(s: Schematic, lib_root: String, sch_path: String = "") -> void:
	_schematic = s
	_lib_root = lib_root
	_sch_path = sch_path
	_symbol_cache.clear()
	_texture_cache.clear()
	_bbox_cache.clear()
	if DirAccess.dir_exists_absolute(lib_root):
		for path in ProjectFs.walk_files(lib_root, ".sym.json"):
			var d = JsonStable.read_file(path)
			if d == null:
				continue
			var id_s := str(d.get("id", ""))
			_symbol_cache[id_s] = d
			_load_symbol_texture(id_s, d)
	queue_redraw()


func reload_from_disk() -> void:
	if _sch_path == "":
		return
	var data = JsonStable.read_file(_sch_path)
	if data == null:
		return
	_schematic = Schematic.from_dict(data)
	queue_redraw()
	schematic_changed.emit()


## 像素 → nm（_nm_to_px 的逆变换）。
func _px_to_nm(px: Vector2) -> Vector2i:
	var world := (px - size * 0.5 - _pan) / (WORLD_PER_NM * _zoom)
	return Vector2i(int(world.x), int(world.y))


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if _sch_path == "":
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return str((data as Dictionary).get("type", "")) == "lib_component"


func _drop_data(at: Vector2, data: Variant) -> void:
	var d := data as Dictionary
	var comp_id: String = str(d.get("id", ""))
	var prefix: String = str(d.get("prefix", "U"))
	if comp_id == "" or _sch_path == "":
		return
	var nm := _px_to_nm(at)
	var reg := CommandRegistry.new()
	SchematicCommands.register(reg)
	## 先消化既有未注解 ?，避免和新 ? 冲突
	reg.call_method("schematic.annotate", {"path": _sch_path})
	var r: Result = reg.call_method("schematic.place_component", {
		"path": _sch_path,
		"component_ref": comp_id,
		"reference": "%s?" % prefix,
		"pos_nm": [nm.x, nm.y],
	})
	if not r.ok:
		push_error("place_component 失败: %s" % r.message)
		return
	reg.call_method("schematic.annotate", {"path": _sch_path})
	reload_from_disk()


func _load_symbol_texture(id_s: String, sym_dict: Dictionary) -> void:
	var sym := ComponentSymbol.from_dict(sym_dict)
	var rendered: Dictionary = SvgIO.render_symbol(sym)
	var svg_str: String = SvgIO.svg_to_string(rendered["viewbox"], rendered["shapes"])
	var img := Image.new()
	var err := img.load_svg_from_buffer(svg_str.to_utf8_buffer(), 4.0)
	if err != OK:
		return
	_texture_cache[id_s] = ImageTexture.create_from_image(img)
	var vb: Array = rendered["viewbox"]
	_bbox_cache[id_s] = Rect2(float(vb[0]), float(vb[1]), float(vb[2]), float(vb[3]))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = clamp(_zoom * 1.15, 0.1, 20.0)
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = clamp(_zoom / 1.15, 0.1, 20.0)
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_active = mb.pressed
			_drag_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit := _find_placement_at(mb.position)
			if hit.is_empty():
				_set_selection("", "", {})
			else:
				_set_selection("placement", str(hit.get("uid", "")), hit)
	elif event is InputEventMouseMotion and _drag_active:
		var mm := event as InputEventMouseMotion
		_pan += mm.position - _drag_last
		_drag_last = mm.position
		queue_redraw()


func _find_placement_at(px: Vector2) -> Dictionary:
	if _schematic == null:
		return {}
	var mm_to_px: float = 1_000_000.0 * WORLD_PER_NM * _zoom
	for pl in _schematic.placements:
		var pos: Array = pl.get("pos_nm", [0, 0])
		var center := _nm_to_px(Vector2i(int(pos[0]), int(pos[1])))
		var sym_id := _symbol_id_for_component(str(pl.get("component_ref", "")))
		var bbox_mm: Rect2 = _bbox_cache.get(sym_id, Rect2()) if sym_id != "" else Rect2()
		var w: float = max(bbox_mm.size.x * mm_to_px, 20.0)
		var h: float = max(bbox_mm.size.y * mm_to_px, 20.0)
		var r := Rect2(center - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
		if r.has_point(px):
			return pl
	return {}


func _set_selection(kind: String, uid: String, data: Dictionary) -> void:
	var prev := _selected_uid
	_selected_uid = uid
	if prev != _selected_uid:
		queue_redraw()
	selection_changed.emit(kind, uid, data)


func get_selected_placement() -> Dictionary:
	if _schematic == null or _selected_uid == "":
		return {}
	return _schematic.find_placement(_selected_uid)


func get_sch_path() -> String:
	return _sch_path


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.12))
	_draw_grid()
	if _schematic == null:
		draw_string(get_theme_default_font(), Vector2(20, 20), "无原理图载入", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		return
	_draw_placements()
	_draw_nets()


func _nm_to_px(p_nm: Vector2i) -> Vector2:
	return Vector2(p_nm.x, p_nm.y) * WORLD_PER_NM * _zoom + _pan + size * 0.5


func _draw_grid() -> void:
	var grid_mm: float = 10.0
	var grid_world: float = grid_mm * 1000000.0 * WORLD_PER_NM * _zoom
	if grid_world < 4:
		return
	var col := Color(0.2, 0.2, 0.25)
	var start := Vector2(fmod(_pan.x + size.x * 0.5, grid_world), fmod(_pan.y + size.y * 0.5, grid_world))
	var x := start.x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
		x += grid_world
	var y := start.y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
		y += grid_world


func _draw_placements() -> void:
	var font := get_theme_default_font()
	## mm → 像素的换算（沿用 nm 路径）：mm → nm × WORLD_PER_NM × _zoom
	var mm_to_px: float = 1_000_000.0 * WORLD_PER_NM * _zoom
	for pl in _schematic.placements:
		var pos: Array = pl.get("pos_nm", [0, 0])
		var center := _nm_to_px(Vector2i(int(pos[0]), int(pos[1])))
		var ref: String = str(pl.get("reference", ""))
		var comp_id: String = str(pl.get("component_ref", ""))
		var sym_id := _symbol_id_for_component(comp_id)
		var tex: ImageTexture = _texture_cache.get(sym_id, null) if sym_id != "" else null
		var bbox_mm: Rect2 = _bbox_cache.get(sym_id, Rect2()) if sym_id != "" else Rect2()
		var is_selected := _selected_uid != "" and str(pl.get("uid", "")) == _selected_uid
		var draw_rect_r: Rect2
		if tex != null and _zoom >= TEXTURE_ZOOM_THRESHOLD and bbox_mm.size.x > 0:
			var w: float = bbox_mm.size.x * mm_to_px
			var h: float = bbox_mm.size.y * mm_to_px
			draw_rect_r = Rect2(center - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
			draw_texture_rect(tex, draw_rect_r, false)
			draw_string(font, draw_rect_r.position + Vector2(0, -4), ref, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		else:
			var half: float = 40.0 * _zoom
			draw_rect_r = Rect2(center - Vector2(half, half), Vector2(half * 2, half * 2))
			draw_rect(draw_rect_r, Color(0.15, 0.45, 0.75), false, 2.0)
			draw_string(font, center + Vector2(-half, -half - 4), ref, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		if is_selected:
			draw_rect(draw_rect_r.grow(4.0), Color(1.0, 0.55, 0.1), false, 2.0)


func _symbol_id_for_component(component_id: String) -> String:
	## 简化映射：component_id 与 symbol_id 同名（demo 现状）。M2 加 component → symbol_ref 解析。
	if _symbol_cache.has(component_id):
		return component_id
	## 兜底：扫一遍找名字匹配（小库可接受）
	for id_s in _symbol_cache.keys():
		if str(id_s) == component_id:
			return str(id_s)
	return ""


func _draw_nets() -> void:
	var placement_pos: Dictionary = {}
	for pl in _schematic.placements:
		var pos: Array = pl.get("pos_nm", [0, 0])
		placement_pos[str(pl.get("reference", ""))] = Vector2i(int(pos[0]), int(pos[1]))
	for n in _schematic.nets:
		var pins: Array = n.get("pins", [])
		if pins.size() < 2:
			continue
		var centers: Array = []
		for pin_ref in pins:
			var parts := str(pin_ref).split(".")
			if parts.size() != 2:
				continue
			var ref := parts[0]
			if placement_pos.has(ref):
				centers.append(_nm_to_px(placement_pos[ref]))
		for i in range(1, centers.size()):
			draw_line(centers[0], centers[i], Color(0.9, 0.7, 0.2), 2.0)
