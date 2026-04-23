extends Node

## 进程级域事件总线。自动载入为 "EventBus"。
## 事件仅传不可变字典快照；订阅者不得反向调用发布者内部状态。

signal component_added(data: Dictionary)
signal schematic_net_changed(data: Dictionary)
signal rule_violated(data: Dictionary)
signal run_completed(data: Dictionary)
## 原理图文件落盘后广播，订阅方（如 SchematicView）按 path 匹配自行 reload。
signal schematic_disk_changed(path: String)


func emit_domain(event: String, payload: Dictionary) -> void:
	match event:
		"component.added": component_added.emit(payload)
		"schematic.net.changed": schematic_net_changed.emit(payload)
		"rule.violated": rule_violated.emit(payload)
		"run.completed": run_completed.emit(payload)
		_:
			push_warning("EventBus: unknown event %s" % event)
