class_name UndoStack
extends RefCounted

## 撤销 / 重做栈（M1.2 P13）。
## 每条条目 {forward: Array[{method, params}], inverse: Array[{method, params}]}。
## MVP 支持 place_component / move_placement / rotate_placement / set_property 的 inverse；
## connect / remove_placement / disconnect_pin 暂不入栈（过渡阶段），避免半成品 restore。
## 上限 100；push 清空 redo；切换工程 clear()。

signal changed

const MAX: int = 100

var _undo: Array = []
var _redo: Array = []
var _registry: CommandRegistry


func _init() -> void:
	_registry = CommandRegistry.new()
	SchematicCommands.register(_registry)


func push(entry: Dictionary) -> void:
	if not entry.has("forward") or not entry.has("inverse"):
		return
	_undo.append(entry)
	while _undo.size() > MAX:
		_undo.pop_front()
	_redo.clear()
	changed.emit()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var e: Dictionary = _undo.pop_back()
	var ok := _run(e.get("inverse", []))
	if ok:
		_redo.append(e)
		changed.emit()
	return ok


func redo() -> bool:
	if _redo.is_empty():
		return false
	var e: Dictionary = _redo.pop_back()
	var ok := _run(e.get("forward", []))
	if ok:
		_undo.append(e)
		changed.emit()
	return ok


func clear() -> void:
	_undo.clear()
	_redo.clear()
	changed.emit()


func _run(cmds: Array) -> bool:
	for cmd in cmds:
		var m: String = str(cmd.get("method", ""))
		var p: Dictionary = cmd.get("params", {})
		var r: Result = _registry.call_method(m, p)
		if not r.ok:
			push_error("undo/redo 执行失败 %s: %s" % [m, r.message])
			return false
	return true


func size() -> int:
	return _undo.size()


func redo_size() -> int:
	return _redo.size()
