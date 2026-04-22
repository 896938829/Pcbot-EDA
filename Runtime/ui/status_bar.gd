class_name StatusBar
extends HBoxContainer

## 状态栏（M1.2 P8）。5 列：
## 1 project · 2 zoom% · 3 mouse mm · 4 selection · 5 last-run

var _project: Label
var _zoom: Label
var _mouse: Label
var _selection: Label
var _last_run: Label


func _ready() -> void:
	_project = _make_label("", SIZE_EXPAND_FILL)
	_zoom = _make_label("zoom 100%", SIZE_FILL, 80)
	_mouse = _make_label("(—, —) mm", SIZE_FILL, 140)
	_selection = _make_label("未选中", SIZE_FILL, 180)
	_last_run = _make_label("", SIZE_FILL, 120)
	set_status("就绪")


func _make_label(text: String, flags: int, min_w: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = flags
	if min_w > 0:
		l.custom_minimum_size = Vector2(min_w, 0)
	add_child(l)
	var sep := VSeparator.new()
	add_child(sep)
	return l


func set_status(text: String) -> void:
	if _project != null:
		_project.text = text


func set_zoom(z: float) -> void:
	if _zoom != null:
		_zoom.text = "zoom %d%%" % int(z * 100.0)


func set_mouse_mm(p: Vector2) -> void:
	if _mouse != null:
		_mouse.text = "(%.1f, %.1f) mm" % [p.x, p.y]


func set_selection(kind: String, label: String) -> void:
	if _selection == null:
		return
	if kind == "":
		_selection.text = "未选中"
	else:
		_selection.text = "[%s] %s" % [kind, label]


func set_last_run(ok: bool, method: String) -> void:
	if _last_run == null:
		return
	var tag := "√" if ok else "×"
	_last_run.text = "%s %s" % [tag, method]
