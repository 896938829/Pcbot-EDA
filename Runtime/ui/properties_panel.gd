extends VBoxContainer

## 右 dock 属性面板骨架。P4 落实 placement / net 字段编辑。


func _ready() -> void:
	var title := Label.new()
	title.text = "属性"
	add_child(title)
	var todo := Label.new()
	todo.text = "P4 TODO: 选中对象字段 / 可编辑 reference / value / rot_deg"
	add_child(todo)
