extends Control

## 主窗口：
## - 新建工程：保存对话框 → project.new + schematic.new
## - 打开工程：文件对话框 → project.open
## - 载入 demo：直接打开 res://demo/led_blink.pcbproj
## M1 只读：不在 UI 层做设计编辑。

@onready var _view: Control = $VBox/SchematicView
@onready var _status: Label = $VBox/Status
@onready var _info: Label = $VBox/Info


func _ready() -> void:
	($VBox/Toolbar/NewBtn as Button).pressed.connect(_on_new_pressed)
	($VBox/Toolbar/OpenBtn as Button).pressed.connect(_on_open_pressed)
	($VBox/Toolbar/DemoBtn as Button).pressed.connect(_on_demo_pressed)

	var args := OS.get_cmdline_args()
	for i in args.size():
		var a: String = args[i]
		if a.ends_with(".pcbproj"):
			_load_project(a)
			return
	_status.text = "工具栏：新建 / 打开 / 载入 demo"
	_info.text = ""


func _on_new_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.pcbproj ; Pcbot 工程"])
	dialog.min_size = Vector2i(700, 500)
	dialog.current_file = "untitled.pcbproj"
	dialog.file_selected.connect(_create_project)
	add_child(dialog)
	dialog.popup_centered()


func _on_open_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.pcbproj ; Pcbot 工程"])
	dialog.min_size = Vector2i(700, 500)
	dialog.file_selected.connect(_load_project)
	add_child(dialog)
	dialog.popup_centered()


func _on_demo_pressed() -> void:
	var demo_path := ProjectSettings.globalize_path("res://demo/led_blink.pcbproj")
	if not FileAccess.file_exists(demo_path):
		_status.text = "未找到 demo: %s" % demo_path
		return
	_load_project(demo_path)


func _create_project(path: String) -> void:
	if not path.ends_with(".pcbproj"):
		path += ".pcbproj"
	path = path.replace("\\", "/")
	var project_name: String = path.get_file().get_basename()
	var sch_rel := "%s.sch.json" % project_name
	var sch_path: String = path.get_base_dir().path_join(sch_rel)

	var reg := CommandRegistry.new()
	ProjectCommands.register(reg)
	SchematicCommands.register(reg)

	var pn: Result = reg.call_method("project.new", {"path": path, "name": project_name})
	if not pn.ok:
		_status.text = "project.new 失败: %s" % pn.message
		return
	var sn: Result = reg.call_method("schematic.new", {"path": sch_path, "id": project_name})
	if not sn.ok:
		_status.text = "schematic.new 失败: %s" % sn.message
		return

	var pj_data = JsonStable.read_file(path)
	var pj := DesignProject.from_dict(pj_data)
	pj.schematic_refs = [sch_rel]
	pj.library_refs = []
	JsonStable.write_file(path, pj.to_dict())

	_status.text = "新建完成: %s" % path
	_load_project(path)


func _load_project(path: String) -> void:
	path = path.replace("\\", "/")
	var data = JsonStable.read_file(path)
	if data == null:
		_status.text = "无法读取: %s" % path
		_info.text = ""
		return
	var project := DesignProject.from_dict(data)
	_status.text = "工程 %s — %s" % [project.name, path]

	var info_lines: Array[String] = []
	info_lines.append("原理图: %d" % project.schematic_refs.size())
	info_lines.append("库引用: %d" % project.library_refs.size())

	if project.schematic_refs.size() == 0:
		info_lines.append("（尚无原理图）")
		_view.set_schematic(null, "")
		_info.text = "\n".join(info_lines)
		return
	var sch_path: String = path.get_base_dir().path_join(project.schematic_refs[0])
	var sch_data = JsonStable.read_file(sch_path)
	if sch_data == null:
		info_lines.append("原理图不可读: %s" % sch_path)
		_info.text = "\n".join(info_lines)
		return
	var sch := Schematic.from_dict(sch_data)
	info_lines.append("元件: %d" % sch.placements.size())
	info_lines.append("网络: %d" % sch.nets.size())
	_info.text = "\n".join(info_lines)

	var lib_root: String = path.get_base_dir().path_join("library")
	_view.set_schematic(sch, lib_root)
