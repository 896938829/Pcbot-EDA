extends VBoxContainer

## 底 dock 日志面板骨架。P5 落实 Logger 订阅 / diagnostics / last-run。


func _ready() -> void:
	var todo := Label.new()
	todo.text = "P5 TODO: Logger 订阅 / .pcbot/diagnostics.jsonl / .pcbot/last-run.json"
	add_child(todo)
