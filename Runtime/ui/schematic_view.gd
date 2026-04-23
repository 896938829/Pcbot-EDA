extends Control

## 原理图只读视图：符号（SVG 纹理优先，回退矩形）、网络连线（中心到中心直线近似）。
## M1.1：SVG 渲染走 SvgIO.render_symbol → ImageTexture 缓存。
## M1 不做 UI 编辑，所有编辑走 CLI。

const WORLD_PER_NM: float = 1.0 / 10000.0  ## 10000 nm = 1 world unit
const TEXTURE_ZOOM_THRESHOLD: float = 0.4  ## 缩放低于此阈值时回退矩形，避免百元件全纹理绘制卡顿

var _undo_stack: UndoStack


func set_undo_stack(u: UndoStack) -> void:
	_undo_stack = u


signal schematic_changed  ## disk 落盘后发出，供属性面板 / 状态栏刷新
signal selection_changed(kind: String, uid: String, data: Dictionary)  ## kind: "placement" or ""
signal hover_changed(uid: String)
signal zoom_changed(zoom: float)
signal mouse_mm_changed(pos_mm: Vector2)

const GRID_DENSITIES_MM: Array = [5.0, 10.0, 25.0]

var _schematic: Schematic
var _symbol_cache: Dictionary = {}      ## id → sym dict
var _texture_cache: Dictionary = {}     ## id → ImageTexture（无纹理则不入）
var _bbox_cache: Dictionary = {}        ## id → Rect2 in mm（用于纹理缩放定位）
var _draw_rect_cache: Dictionary = {}   ## uid → Rect2 in px（上一帧真实绘制矩形，供 hit-test）
var _lib_root: String = ""
var _sch_path: String = ""               ## 当前原理图文件路径（drop/编辑落盘用）
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _drag_active: bool = false
var _drag_last: Vector2
var _selected_uid: String = ""  ## 当前选中的 placement uid，""=无选中
var _hovered_uid: String = ""   ## 当前鼠标悬停的 placement uid
var _grid_visible: bool = true
var _grid_density_idx: int = 1   ## index into GRID_DENSITIES_MM, 默认 10mm
var _move_active: bool = false
var _move_uid: String = ""
var _move_start_pos_nm: Array = [0, 0]
var _move_start_px: Vector2 = Vector2.ZERO
var _move_offset_px: Vector2 = Vector2.ZERO
var _wire_first_pin: String = ""  ## "<reference>.<pin_number>"
var _wire_first_px: Vector2 = Vector2.ZERO
var _wire_mouse_px: Vector2 = Vector2.ZERO

const PIN_HIT_RADIUS_PX: float = 8.0
const PIN_DOT_RADIUS_PX: float = 3.0


func _ready() -> void:
	_build_zoom_overlay()
	focus_mode = Control.FOCUS_ALL
	clip_contents = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var k := event as InputEventKey
	if k.keycode == KEY_DELETE and _selected_uid != "":
		_delete_selected()
		accept_event()
	elif k.keycode == KEY_ESCAPE:
		_cancel_wiring()
		accept_event()


func _delete_selected() -> void:
	if _sch_path == "" or _selected_uid == "":
		return
	var reg := CommandRegistry.new()
	SchematicCommands.register(reg)
	var r: Result = reg.call_method(
		"schematic.remove_placement",
		{"path": _sch_path, "placement_uid": _selected_uid}
	)
	if r.ok:
		_set_selection("", "", {})
		reload_from_disk()
	else:
		push_error("remove_placement 失败: %s" % r.message)


func _build_zoom_overlay() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -220
	row.offset_top = -32
	row.offset_right = -4
	row.offset_bottom = -4
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(row)
	var btn_minus := Button.new()
	btn_minus.text = "−"
	btn_minus.custom_minimum_size = Vector2(28, 24)
	btn_minus.pressed.connect(zoom_out)
	row.add_child(btn_minus)
	var btn_plus := Button.new()
	btn_plus.text = "+"
	btn_plus.custom_minimum_size = Vector2(28, 24)
	btn_plus.pressed.connect(zoom_in)
	row.add_child(btn_plus)
	var btn_100 := Button.new()
	btn_100.text = "100%"
	btn_100.pressed.connect(zoom_reset)
	row.add_child(btn_100)
	var btn_fit := Button.new()
	btn_fit.text = "Fit"
	btn_fit.pressed.connect(zoom_fit)
	row.add_child(btn_fit)
	var btn_grid := Button.new()
	btn_grid.text = "网格"
	btn_grid.pressed.connect(cycle_grid_density)
	row.add_child(btn_grid)


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
	var place_params: Dictionary = {
		"path": _sch_path,
		"component_ref": comp_id,
		"reference": "%s?" % prefix,
		"pos_nm": [nm.x, nm.y],
	}
	var r: Result = reg.call_method("schematic.place_component", place_params)
	if not r.ok:
		push_error("place_component 失败: %s" % r.message)
		return
	var new_uid := str(r.data.get("uid", ""))
	reg.call_method("schematic.annotate", {"path": _sch_path})
	if _undo_stack != null and new_uid != "":
		_undo_stack.push({
			"forward": [{"method": "schematic.place_component", "params": place_params}],
			"inverse": [{"method": "schematic.remove_placement",
						 "params": {"path": _sch_path, "placement_uid": new_uid}}],
		})
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
			set_zoom(_zoom * 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_zoom(_zoom / 1.15)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_active = mb.pressed
			_drag_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var pin_hit := _find_pin_at(mb.position)
				if not pin_hit.is_empty():
					_handle_pin_click(pin_hit)
					return
				var hit := _find_placement_at(mb.position)
				if hit.is_empty():
					_set_selection("", "", {})
					_cancel_wiring()
				else:
					_set_selection("placement", str(hit.get("uid", "")), hit)
					_move_active = true
					_move_uid = str(hit.get("uid", ""))
					_move_start_pos_nm = hit.get("pos_nm", [0, 0])
					_move_start_px = mb.position
					_move_offset_px = Vector2.ZERO
			else:
				## release：若真的拖动（偏移 > 2 px）则调 move_placement 落盘
				if _move_active and _move_offset_px.length() > 2.0:
					_apply_move()
				_move_active = false
				_move_uid = ""
				_move_offset_px = Vector2.ZERO
				queue_redraw()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_active:
			_pan += mm.position - _drag_last
			_drag_last = mm.position
			queue_redraw()
		if _move_active:
			_move_offset_px = mm.position - _move_start_px
			queue_redraw()
		if _wire_first_pin != "":
			_wire_mouse_px = mm.position
			queue_redraw()
		var nm := _px_to_nm(mm.position)
		mouse_mm_changed.emit(Vector2(nm.x, nm.y) / 1_000_000.0)
		var hit := _find_placement_at(mm.position)
		var new_hover := str(hit.get("uid", ""))
		if new_hover != _hovered_uid:
			_hovered_uid = new_hover
			hover_changed.emit(_hovered_uid)
			queue_redraw()


func _find_pin_at(px: Vector2) -> Dictionary:
	if _schematic == null:
		return {}
	for pl in _schematic.placements:
		var ref: String = str(pl.get("reference", ""))
		var pos: Array = pl.get("pos_nm", [0, 0])
		var sym_id := _symbol_id_for_component(str(pl.get("component_ref", "")))
		var sym_dict: Dictionary = _symbol_cache.get(sym_id, {})
		if not sym_dict.has("pins"):
			continue
		for pin in sym_dict["pins"]:
			var pin_pos: Array = pin.get("pos", [0, 0])
			var world_nm := Vector2i(int(pos[0]) + int(pin_pos[0]), int(pos[1]) + int(pin_pos[1]))
			var pin_px := _nm_to_px(world_nm)
			if (px - pin_px).length() <= PIN_HIT_RADIUS_PX:
				return {
					"pin_ref": "%s.%s" % [ref, str(pin.get("number", ""))],
					"pin_px": pin_px,
				}
	return {}


func _handle_pin_click(hit: Dictionary) -> void:
	var pin_ref: String = str(hit.get("pin_ref", ""))
	var pin_px: Vector2 = hit.get("pin_px", Vector2.ZERO)
	if _wire_first_pin == "":
		_wire_first_pin = pin_ref
		_wire_first_px = pin_px
		_wire_mouse_px = pin_px
		queue_redraw()
	else:
		if pin_ref == _wire_first_pin:
			_cancel_wiring()
			return
		_apply_wire(_wire_first_pin, pin_ref)
		_cancel_wiring()


func _apply_wire(a: String, b: String) -> void:
	if _sch_path == "":
		return
	var reg := CommandRegistry.new()
	SchematicCommands.register(reg)
	var r: Result = reg.call_method(
		"schematic.connect",
		{"path": _sch_path, "net": "", "pins": [a, b]}
	)
	if r.ok:
		reload_from_disk()
	else:
		push_error("connect 失败: %s" % r.message)


func _cancel_wiring() -> void:
	if _wire_first_pin != "":
		_wire_first_pin = ""
		queue_redraw()


func _apply_move() -> void:
	if _sch_path == "" or _move_uid == "":
		return
	## offset_px → offset_nm
	var offset_nm: Vector2 = _move_offset_px / (WORLD_PER_NM * _zoom)
	var new_x: int = int(_move_start_pos_nm[0]) + int(offset_nm.x)
	var new_y: int = int(_move_start_pos_nm[1]) + int(offset_nm.y)
	var reg := CommandRegistry.new()
	SchematicCommands.register(reg)
	var forward := {
		"method": "schematic.move_placement",
		"params": {"path": _sch_path, "placement_uid": _move_uid, "pos_nm": [new_x, new_y]},
	}
	var inverse := {
		"method": "schematic.move_placement",
		"params": {"path": _sch_path, "placement_uid": _move_uid,
				   "pos_nm": [int(_move_start_pos_nm[0]), int(_move_start_pos_nm[1])]},
	}
	var r: Result = reg.call_method(forward.method, forward.params)
	if r.ok:
		if _undo_stack != null:
			_undo_stack.push({"forward": [forward], "inverse": [inverse]})
		reload_from_disk()
	else:
		push_error("move_placement 失败: %s" % r.message)


func _find_placement_at(px: Vector2) -> Dictionary:
	if _schematic == null:
		return {}
	## 优先走上一帧真实绘制矩形缓存（与 _draw_placements 对齐，消除 hit/draw 错位）。
	for uid in _draw_rect_cache.keys():
		var rect: Rect2 = _draw_rect_cache[uid]
		if rect.has_point(px):
			var pl_hit: Dictionary = _schematic.find_placement(str(uid))
			if not pl_hit.is_empty():
				return pl_hit
	## 回退：未绘制过（首帧）时按 bbox 兜底。
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


func get_zoom() -> float:
	return _zoom


func set_zoom(z: float) -> void:
	_zoom = clamp(z, 0.1, 20.0)
	queue_redraw()
	zoom_changed.emit(_zoom)


func zoom_in() -> void:
	set_zoom(_zoom * 1.25)


func zoom_out() -> void:
	set_zoom(_zoom / 1.25)


func zoom_reset() -> void:
	_pan = Vector2.ZERO
	set_zoom(1.0)


func zoom_fit() -> void:
	## 简单 fit：计算所有 placement bounding box，缩放到视口 80%。
	if _schematic == null or _schematic.placements.is_empty():
		zoom_reset()
		return
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for pl in _schematic.placements:
		var pos: Array = pl.get("pos_nm", [0, 0])
		min_x = min(min_x, float(pos[0]))
		min_y = min(min_y, float(pos[1]))
		max_x = max(max_x, float(pos[0]))
		max_y = max(max_y, float(pos[1]))
	var world_w := (max_x - min_x) * WORLD_PER_NM
	var world_h := (max_y - min_y) * WORLD_PER_NM
	if world_w <= 0 or world_h <= 0:
		zoom_reset()
		return
	var zx: float = size.x * 0.8 / world_w
	var zy: float = size.y * 0.8 / world_h
	_pan = Vector2.ZERO
	set_zoom(min(zx, zy))


func toggle_grid() -> void:
	_grid_visible = not _grid_visible
	queue_redraw()


func cycle_grid_density() -> void:
	_grid_density_idx = (_grid_density_idx + 1) % GRID_DENSITIES_MM.size()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.12))
	if _grid_visible:
		_draw_grid()
	if _schematic == null:
		draw_string(get_theme_default_font(), Vector2(20, 20), "无原理图载入", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		return
	_draw_placements()
	_draw_nets()
	_draw_pins()
	_draw_wire_preview()


func _nm_to_px(p_nm: Vector2i) -> Vector2:
	return Vector2(p_nm.x, p_nm.y) * WORLD_PER_NM * _zoom + _pan + size * 0.5


func _draw_pins() -> void:
	if _schematic == null:
		return
	for pl in _schematic.placements:
		var pos: Array = pl.get("pos_nm", [0, 0])
		var sym_id := _symbol_id_for_component(str(pl.get("component_ref", "")))
		var sym_dict: Dictionary = _symbol_cache.get(sym_id, {})
		if not sym_dict.has("pins"):
			continue
		for pin in sym_dict["pins"]:
			var pin_pos: Array = pin.get("pos", [0, 0])
			var world_nm := Vector2i(int(pos[0]) + int(pin_pos[0]), int(pos[1]) + int(pin_pos[1]))
			var px := _nm_to_px(world_nm)
			draw_circle(px, PIN_DOT_RADIUS_PX, Color(0.9, 0.7, 0.2))


func _draw_wire_preview() -> void:
	if _wire_first_pin == "":
		return
	draw_circle(_wire_first_px, PIN_DOT_RADIUS_PX + 2.0, Color(0.3, 0.9, 0.3))
	draw_dashed_line(_wire_first_px, _wire_mouse_px, Color(0.3, 0.9, 0.3), 1.5)


func _draw_grid() -> void:
	var grid_mm: float = GRID_DENSITIES_MM[_grid_density_idx]
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
	_draw_rect_cache.clear()
	for pl in _schematic.placements:
		var pos: Array = pl.get("pos_nm", [0, 0])
		var center := _nm_to_px(Vector2i(int(pos[0]), int(pos[1])))
		if _move_active and str(pl.get("uid", "")) == _move_uid:
			center += _move_offset_px
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
		elif _hovered_uid != "" and str(pl.get("uid", "")) == _hovered_uid:
			draw_rect(draw_rect_r.grow(3.0), Color(1.0, 0.9, 0.2, 0.8), false, 1.5)
		var uid_s := str(pl.get("uid", ""))
		if uid_s != "":
			_draw_rect_cache[uid_s] = draw_rect_r


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
