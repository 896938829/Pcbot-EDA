class_name PropertiesPanel
extends VBoxContainer

## 属性面板（M1.2 P4）。
## - 监听 SchematicView.selection_changed → 渲染字段
## - 可编辑：reference（回车 → set_property）、rotation_deg（选择 → rotate_placement）
## - mirror 复选框 → set_property
## - pos_nm / uid / component_ref 只读展示

var _kind: String = ""
var _uid: String = ""
var _data: Dictionary = {}

var _title: Label
var _row_uid: Label
var _row_comp: Label
var _row_pos: Label
var _ref_edit: LineEdit
var _rot_option: OptionButton
var _mirror_check: CheckBox
var _status: Label

var _sch_path_getter: Callable
var _undo_stack: UndoStack

const ROTATIONS: Array = [0, 90, 180, 270]


func set_undo_stack(u: UndoStack) -> void:
	_undo_stack = u


func _ready() -> void:
	_title = Label.new()
	_title.text = "属性"
	add_child(_title)

	_row_uid = Label.new()
	add_child(_row_uid)
	_row_comp = Label.new()
	add_child(_row_comp)
	_row_pos = Label.new()
	add_child(_row_pos)

	var ref_label := Label.new()
	ref_label.text = "reference"
	add_child(ref_label)
	_ref_edit = LineEdit.new()
	_ref_edit.placeholder_text = "reference（回车提交）"
	_ref_edit.text_submitted.connect(_on_reference_submitted)
	add_child(_ref_edit)

	var rot_label := Label.new()
	rot_label.text = "rotation_deg"
	add_child(rot_label)
	_rot_option = OptionButton.new()
	for deg in ROTATIONS:
		_rot_option.add_item(str(deg))
	_rot_option.item_selected.connect(_on_rot_selected)
	## reference 回车会把焦点冒泡到下一个 FOCUS_ALL 控件（即 OptionButton），
	## Enter 再被吃掉触发下拉。限定只能点击聚焦，避免键盘抢焦。
	_rot_option.focus_mode = Control.FOCUS_CLICK
	add_child(_rot_option)

	_mirror_check = CheckBox.new()
	_mirror_check.text = "mirror"
	_mirror_check.toggled.connect(_on_mirror_toggled)
	add_child(_mirror_check)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 40)
	add_child(_status)

	_render_empty()


## 由主窗口注入：返回当前 sch 文件路径（随载入工程变化）。
func set_sch_path_getter(getter: Callable) -> void:
	_sch_path_getter = getter


## 连接到 SchematicView.selection_changed 信号。
func on_selection_changed(kind: String, uid: String, data: Dictionary) -> void:
	_kind = kind
	_uid = uid
	_data = data
	if kind == "placement":
		_render_placement(data)
	else:
		_render_empty()


func _render_empty() -> void:
	_row_uid.text = "uid: —"
	_row_comp.text = "component_ref: —"
	_row_pos.text = "pos_nm: —"
	_ref_edit.text = ""
	_ref_edit.editable = false
	_rot_option.disabled = true
	_mirror_check.disabled = true
	_mirror_check.button_pressed = false
	_status.text = "未选中对象"


func _render_placement(d: Dictionary) -> void:
	_row_uid.text = "uid: %s" % str(d.get("uid", ""))
	_row_comp.text = "component_ref: %s" % str(d.get("component_ref", ""))
	var pos: Array = d.get("pos_nm", [0, 0])
	_row_pos.text = "pos_nm: [%s, %s]" % [str(pos[0]), str(pos[1])]
	_ref_edit.text = str(d.get("reference", ""))
	_ref_edit.editable = true
	var rot := int(d.get("rotation_deg", 0))
	var idx := ROTATIONS.find(rot)
	_rot_option.disabled = false
	_rot_option.select(max(idx, 0))
	_mirror_check.disabled = false
	_mirror_check.button_pressed = bool(d.get("mirror", false))
	_status.text = "选中 placement %s" % str(d.get("reference", ""))


func _sch_path() -> String:
	if _sch_path_getter.is_valid():
		return str(_sch_path_getter.call())
	return ""


func _call(method: String, params: Dictionary) -> Result:
	var reg := CommandRegistry.new()
	SchematicCommands.register(reg)
	var r: Result = reg.call_method(method, params)
	## PropertiesPanel 不持有 SchematicView 引用；走 EventBus 广播让 view 按 path 自行 reload。
	if r.ok:
		EventBus.schematic_disk_changed.emit(str(params.get("path", "")))
	return r


func _push_undo(forward: Dictionary, inverse: Dictionary) -> void:
	if _undo_stack == null:
		return
	_undo_stack.push({"forward": [forward], "inverse": [inverse]})


func _on_reference_submitted(text: String) -> void:
	if _kind != "placement" or _uid == "":
		return
	var path := _sch_path()
	if path == "":
		_status.text = "无 sch_path，拒绝提交"
		return
	var prev: String = str(_data.get("reference", ""))
	var params := {"path": path, "placement_uid": _uid, "key": "reference", "value": text}
	var r: Result = _call("schematic.set_property", params)
	if r.ok:
		_data["reference"] = text
		_push_undo(
			{"method": "schematic.set_property", "params": params},
			{"method": "schematic.set_property",
			 "params": {"path": path, "placement_uid": _uid, "key": "reference", "value": prev}}
		)
		_status.text = "reference = %s" % text
	else:
		_status.text = "失败: %s" % r.message
	## 提交后显式释放焦点，避免 Enter 冒泡到下一个控件触发意外操作。
	_ref_edit.release_focus()


func _on_rot_selected(idx: int) -> void:
	if _kind != "placement" or _uid == "":
		return
	var path := _sch_path()
	if path == "":
		return
	var deg: int = ROTATIONS[idx]
	var prev: int = int(_data.get("rotation_deg", 0))
	if prev == deg:
		return
	var params := {"path": path, "placement_uid": _uid, "rotation_deg": deg}
	var r: Result = _call("schematic.rotate_placement", params)
	if r.ok:
		_data["rotation_deg"] = deg
		_push_undo(
			{"method": "schematic.rotate_placement", "params": params},
			{"method": "schematic.rotate_placement",
			 "params": {"path": path, "placement_uid": _uid, "rotation_deg": prev}}
		)
		_status.text = "rotation_deg = %d" % deg
	else:
		_status.text = "失败: %s" % r.message


func _on_mirror_toggled(pressed: bool) -> void:
	if _kind != "placement" or _uid == "":
		return
	var path := _sch_path()
	if path == "":
		return
	var prev: bool = bool(_data.get("mirror", false))
	if prev == pressed:
		return
	var params := {"path": path, "placement_uid": _uid, "key": "mirror", "value": pressed}
	var r: Result = _call("schematic.set_property", params)
	if r.ok:
		_data["mirror"] = pressed
		_push_undo(
			{"method": "schematic.set_property", "params": params},
			{"method": "schematic.set_property",
			 "params": {"path": path, "placement_uid": _uid, "key": "mirror", "value": prev}}
		)
		_status.text = "mirror = %s" % str(pressed)
	else:
		_status.text = "失败: %s" % r.message
