extends Control

## 主窗口：文件对话 → 加载工程 → 渲染原理图（只读，M1）。

@onready var _view: Control = $VBox/SchematicView
@onready var _status: Label = $VBox/Status


func _ready() -> void:
	var open_btn: Button = $VBox/Toolbar/OpenBtn
	open_btn.pressed.connect(_on_open_pressed)
	var args := OS.get_cmdline_args()
	for i in args.size():
		var a: String = args[i]
		if a.ends_with(".pcbproj"):
			_load_project(a)
			return
	_status.text = "用 '打开工程' 载入 *.pcbproj"


func _on_open_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.pcbproj ; Pcbot 工程"])
	dialog.min_size = Vector2i(700, 500)
	dialog.file_selected.connect(_load_project)
	add_child(dialog)
	dialog.popup_centered()


func _load_project(path: String) -> void:
	var data = JsonStable.read_file(path)
	if data == null:
		_status.text = "无法读取: %s" % path
		return
	var project := DesignProject.from_dict(data)
	_status.text = "工程 %s · %d 个原理图" % [project.name, project.schematic_refs.size()]
	if project.schematic_refs.size() == 0:
		return
	var sch_path: String = path.get_base_dir().path_join(project.schematic_refs[0])
	var sch_data = JsonStable.read_file(sch_path)
	if sch_data == null:
		return
	var lib_root: String = path.get_base_dir().path_join("library")
	_view.set_schematic(Schematic.from_dict(sch_data), lib_root)
