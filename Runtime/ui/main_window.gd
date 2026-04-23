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
@onready var _status_bar: StatusBar = $VBox/StatusBar
@onready var _menu_file: PopupMenu = $VBox/MenuBar/文件
@onready var _menu_edit: PopupMenu = $VBox/MenuBar/编辑
@onready var _menu_view: PopupMenu = $VBox/MenuBar/视图
@onready var _menu_help: PopupMenu = $VBox/MenuBar/帮助
@onready var _left_dock: Control = $VBox/MainSplit/LeftDock
@onready var _right_dock: Control = $VBox/MainSplit/MidRightSplit/RightDock
@onready var _bottom_tabs: Control = $VBox/MainSplit/MidRightSplit/CenterSplit/BottomTabs

var _current_sch_path: String = ""
var _undo: UndoStack = UndoStack.new()
var _prefs: Prefs = Prefs.new()
var _recent_submenu: PopupMenu

enum EditMenuId { UNDO = 1, REDO = 2, DELETE = 3 }
enum ViewMenuId { LEFT_DOCK = 1, RIGHT_DOCK = 2, BOTTOM_DOCK = 3, GRID = 4 }
enum HelpMenuId { ABOUT = 1 }

const APP_VERSION := "0.1.0 (M1.2)"

enum FileMenuId { NEW = 1, OPEN = 2, DEMO = 3, QUIT = 9 }
const RECENT_ID_BASE: int = 100  ## recent 项 id = base + index


func _ready() -> void:
	_prefs.load()

	_menu_file.add_item("新建工程", FileMenuId.NEW)
	_menu_file.add_item("打开工程", FileMenuId.OPEN)
	_menu_file.add_item("载入 Demo", FileMenuId.DEMO)
	_recent_submenu = PopupMenu.new()
	_recent_submenu.name = "最近工程"
	_recent_submenu.id_pressed.connect(_on_recent_picked)
	_menu_file.add_child(_recent_submenu)
	_menu_file.add_submenu_item("最近工程", "最近工程")
	_menu_file.add_separator()
	_menu_file.add_item("退出", FileMenuId.QUIT)
	_menu_file.id_pressed.connect(_on_file_menu)
	_rebuild_recent_menu()

	_menu_edit.add_item("撤销 (Ctrl+Z)", EditMenuId.UNDO)
	_menu_edit.add_item("重做 (Ctrl+Y)", EditMenuId.REDO)
	_menu_edit.add_separator()
	_menu_edit.add_item("删除选中 (Del)", EditMenuId.DELETE)
	_menu_edit.id_pressed.connect(_on_edit_menu)

	_menu_view.add_check_item("左侧元件库", ViewMenuId.LEFT_DOCK)
	_menu_view.add_check_item("右侧属性", ViewMenuId.RIGHT_DOCK)
	_menu_view.add_check_item("底部日志+CLI", ViewMenuId.BOTTOM_DOCK)
	_menu_view.add_separator()
	_menu_view.add_check_item("网格", ViewMenuId.GRID)
	_menu_view.id_pressed.connect(_on_view_menu)
	## apply 持久化偏好
	_left_dock.visible = bool(_prefs.get_value("dock_left", true))
	_right_dock.visible = bool(_prefs.get_value("dock_right", true))
	_bottom_tabs.visible = bool(_prefs.get_value("dock_bottom", true))
	_menu_view.set_item_checked(_menu_view.get_item_index(ViewMenuId.LEFT_DOCK), _left_dock.visible)
	_menu_view.set_item_checked(_menu_view.get_item_index(ViewMenuId.RIGHT_DOCK), _right_dock.visible)
	_menu_view.set_item_checked(_menu_view.get_item_index(ViewMenuId.BOTTOM_DOCK), _bottom_tabs.visible)
	_menu_view.set_item_checked(_menu_view.get_item_index(ViewMenuId.GRID), true)

	_menu_help.add_item("关于 Pcbot EDA", HelpMenuId.ABOUT)
	_menu_help.id_pressed.connect(_on_help_menu)

	_view.set_undo_stack(_undo)
	_properties_panel.set_undo_stack(_undo)

	_view.selection_changed.connect(_properties_panel.on_selection_changed)
	_view.schematic_changed.connect(_on_schematic_changed)
	_view.zoom_changed.connect(_status_bar.set_zoom)
	_view.mouse_mm_changed.connect(_status_bar.set_mouse_mm)
	_view.selection_changed.connect(_on_view_selection_for_status)
	_properties_panel.set_sch_path_getter(Callable(self, "_get_current_sch_path"))

	var args := OS.get_cmdline_args()
	for i in args.size():
		var a: String = args[i]
		if a.ends_with(".pcbproj"):
			_load_project(a)
			return
	_set_status("就绪 · 文件 菜单 新建 / 打开 / 载入 Demo")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var k := event as InputEventKey
	if k.ctrl_pressed and k.keycode == KEY_Z:
		if _undo.undo():
			_view.reload_from_disk()
			_set_status("撤销 · 栈 %d" % _undo.size())
		accept_event()
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		if _undo.redo():
			_view.reload_from_disk()
			_set_status("重做 · 栈 %d" % _undo.size())
		accept_event()


func _on_view_menu(id: int) -> void:
	var idx := _menu_view.get_item_index(id)
	var checked := not _menu_view.is_item_checked(idx)
	_menu_view.set_item_checked(idx, checked)
	match id:
		ViewMenuId.LEFT_DOCK:
			_left_dock.visible = checked
			_prefs.set_value("dock_left", checked)
		ViewMenuId.RIGHT_DOCK:
			_right_dock.visible = checked
			_prefs.set_value("dock_right", checked)
		ViewMenuId.BOTTOM_DOCK:
			_bottom_tabs.visible = checked
			_prefs.set_value("dock_bottom", checked)
		ViewMenuId.GRID:
			_view.toggle_grid()


func _rebuild_recent_menu() -> void:
	_recent_submenu.clear()
	var list: Array = _prefs.recent()
	if list.is_empty():
		_recent_submenu.add_item("(无)", RECENT_ID_BASE - 1)
		_recent_submenu.set_item_disabled(0, true)
		return
	for i in list.size():
		_recent_submenu.add_item(str(list[i]), RECENT_ID_BASE + i)


func _on_recent_picked(id: int) -> void:
	var list: Array = _prefs.recent()
	var idx := id - RECENT_ID_BASE
	if idx < 0 or idx >= list.size():
		return
	_load_project(str(list[idx]))


func _on_help_menu(id: int) -> void:
	if id == HelpMenuId.ABOUT:
		var dlg := AcceptDialog.new()
		dlg.title = "关于"
		dlg.dialog_text = "Pcbot EDA %s\n\nAI 驱动的 PCB EDA 工具\nADR-0005: GUI 是一等编辑面\nCLI 仍是 AI 唯一接入面" % APP_VERSION
		add_child(dlg)
		dlg.popup_centered()


func _on_edit_menu(id: int) -> void:
	match id:
		EditMenuId.UNDO:
			if _undo.undo():
				_view.reload_from_disk()
		EditMenuId.REDO:
			if _undo.redo():
				_view.reload_from_disk()
		EditMenuId.DELETE:
			_view._delete_selected()


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
	_undo.clear()
	_prefs.add_recent(path)
	_rebuild_recent_menu()
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


func _on_view_selection_for_status(kind: String, _uid: String, data: Dictionary) -> void:
	_status_bar.set_selection(kind, str(data.get("reference", "")))
