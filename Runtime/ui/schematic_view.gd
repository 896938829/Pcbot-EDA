extends Control

## 原理图只读视图：符号（矩形+文字代替）、网络连线（以放置中心到中心直线近似）。
## M1 不做 UI 编辑，所有编辑走 CLI。

const WORLD_PER_NM: float = 1.0 / 10000.0  ## 10000 nm = 1 world unit

var _schematic: Schematic
var _symbol_cache: Dictionary = {}
var _lib_root: String = ""
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _drag_active: bool = false
var _drag_last: Vector2


func set_schematic(s: Schematic, lib_root: String) -> void:
	_schematic = s
	_lib_root = lib_root
	_symbol_cache.clear()
	if DirAccess.dir_exists_absolute(lib_root):
		for path in ProjectFs.walk_files(lib_root, ".sym.json"):
			var d = JsonStable.read_file(path)
			if d != null:
				_symbol_cache[str(d.get("id", ""))] = d
	queue_redraw()


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
	elif event is InputEventMouseMotion and _drag_active:
		var mm := event as InputEventMouseMotion
		_pan += mm.position - _drag_last
		_drag_last = mm.position
		queue_redraw()


func _draw() -> void:
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
	for pl in _schematic.placements:
		var pos: Array = pl.get("pos_nm", [0, 0])
		var p := _nm_to_px(Vector2i(int(pos[0]), int(pos[1])))
		var half: float = 40.0 * _zoom
		var rect := Rect2(p - Vector2(half, half), Vector2(half * 2, half * 2))
		draw_rect(rect, Color(0.15, 0.45, 0.75), false, 2.0)
		draw_string(font, p + Vector2(-half, -half - 4), str(pl.get("reference", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


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
