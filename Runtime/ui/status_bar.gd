extends HBoxContainer

## 状态栏骨架。P8 扩成 5 列（工程 / zoom / mouse mm / 选中 / last-run）。

var _status_label: Label


func _ready() -> void:
	_status_label = Label.new()
	_status_label.text = "Pcbot"
	add_child(_status_label)


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
