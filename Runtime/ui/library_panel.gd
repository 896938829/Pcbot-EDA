extends VBoxContainer

## 左 dock 元件库面板骨架。P3 落实搜索 / 树 / 拖拽。


func _ready() -> void:
	var title := Label.new()
	title.text = "元件库"
	add_child(title)
	var todo := Label.new()
	todo.text = "P3 TODO: 搜索 / Tree / SVG 预览 / 拖拽"
	add_child(todo)
