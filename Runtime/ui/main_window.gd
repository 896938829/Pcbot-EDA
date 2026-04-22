extends Control

## 主窗口：4-dock 布局（M1.2 P2 骨架）。
## - 顶部 MenuBar（文件 / 编辑 / 视图 / 帮助）
## - 左 dock LibraryPanel / 中 SchematicView + 底 TabContainer(日志|CLI) / 右 PropertiesPanel
## - 底 StatusBar
## 设计编辑走 CLI 命令（ADR-0005）；本文件只做入口装配与菜单触发。

@onready var _view: Control = $VBox/MainSplit/MidRightSplit/CenterSplit/SchematicView
@onready var _library_panel: LibraryPanel = $VBox/MainSplit/LeftDock
@onready var _properties_panel: PropertiesPanel = $VBox/MainSplit/MidRightSplit/RightDock
@onready var _log_panel: LogPanel = $VBox/MainSplit/MidRightSplit/CenterSplit/BottomTabs/日志
@onready var _status_bar: HBoxContainer = $VBox/StatusBar
@onready var _menu_file: PopupMenu = $VBox/MenuBar/文件

var _current_sch_path: String = ""

enum FileMenuId { NEW = 1, OPEN = 2, DEMO = 3, QUIT = 9 }


func _ready() -> void:
	_menu_file.add_item("新建工程", FileMenuId.NEW)
	_menu_file.add_item("打开工程", FileMenuId.OPEN)
	_menu_file.add_item("载入 Demo", FileMenuId.DEMO)
	_menu_file.add_separator()
	_menu_file.add_item("退出", FileMenuId.QUIT)
	_menu_file.id_pressed.connect(_on_file_menu)

	_view.selection_changed.connect(_properties_panel.on_selection_changed)
	_view.schematic_changed.connect(_on_schematic_changed)
	_properties_panel.set_sch_path_getter(Callable(self, "_get_current_sch_path"))

	var args := OS.get_cmdline_args()
	for i in args.size():
		var a: String = args[i]
		if a.ends_with(".pcbproj"):
			_load_project(a)
			return
	_set_status("就绪 · 文件 菜单 新建 / 打开 / 载入 Demo")


func _on_file_menu(id: int) -> void:
	match id:
		FileMenuId.NEW:
			_on_new_pressed()
		FileMenuId.OPEN:
			_on_open_pressed()
		FileMenuId.DEMO:
			_on_demo_pressed()
		FileMenuId.QUIT:
			get_tree().quit()


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
		_set_status("未找到 demo: %s" % demo_path)
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
		_set_status("project.new 失败: %s" % pn.message)
		return
	var sn: Result = reg.call_method("schematic.new", {"path": sch_path, "id": project_name})
	if not sn.ok:
		_set_status("schematic.new 失败: %s" % sn.message)
		return

	var pj_data = JsonStable.read_file(path)
	var pj := DesignProject.from_dict(pj_data)
	pj.schematic_refs = [sch_rel]
	pj.library_refs = []
	JsonStable.write_file(path, pj.to_dict())

	_set_status("新建完成: %s" % path)
	_load_project(path)


func _load_project(path: String) -> void:
	path = path.replace("\\", "/")
	var data = JsonStable.read_file(path)
	if data == null:
		_set_status("无法读取: %s" % path)
		return
	var project := DesignProject.from_dict(data)

	var lib_root: String = path.get_base_dir().path_join("library")
	_library_panel.set_library_root(lib_root)
	_log_panel.set_project_root(path.get_base_dir())
	if project.schematic_refs.size() == 0:
		_current_sch_path = ""
		_view.set_schematic(null, "", "")
		_set_status("工程 %s · 原理图 0 · 库引用 %d" % [project.name, project.library_refs.size()])
		return
	var sch_path: String = path.get_base_dir().path_join(project.schematic_refs[0])
	var sch_data = JsonStable.read_file(sch_path)
	if sch_data == null:
		_set_status("原理图不可读: %s" % sch_path)
		return
	var sch := Schematic.from_dict(sch_data)
	_current_sch_path = sch_path
	_view.set_schematic(sch, lib_root, sch_path)
	_set_status(
		(
			"工程 %s · 元件 %d · 网络 %d · 库引用 %d"
			% [project.name, sch.placements.size(), sch.nets.size(), project.library_refs.size()]
		)
	)


func _set_status(text: String) -> void:
	if _status_bar != null and _status_bar.has_method("set_status"):
		_status_bar.set_status(text)


func _get_current_sch_path() -> String:
	return _current_sch_path


func _on_schematic_changed() -> void:
	## disk 落盘后：若当前选中 placement 仍存在，刷新属性面板字段
	var sel: Dictionary = _view.get_selected_placement()
	if sel.is_empty():
		_properties_panel.on_selection_changed("", "", {})
	else:
		_properties_panel.on_selection_changed("placement", str(sel.get("uid", "")), sel)
