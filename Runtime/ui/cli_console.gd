extends VBoxContainer

## 底 dock CLI 调试面板骨架。P6 落实 JSON-RPC 输入 / 历史 / 响应展示。


func _ready() -> void:
	var todo := Label.new()
	todo.text = "P6 TODO: JSON-RPC 单行输入 / 历史 ≥20 条 / 响应折叠高亮"
	add_child(todo)
