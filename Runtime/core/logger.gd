extends Node

## 结构化日志。自动载入为 "Logger"。输出到 stderr（不污染 stdout 的 JSON-RPC 响应）。

enum Level { DEBUG, INFO, WARN, ERROR }

signal log_emitted(level: int, module: String, message: String, fields: Dictionary)

var min_level: int = Level.INFO


func set_level(level: int) -> void:
	min_level = level


func debug(module: String, message: String, fields: Dictionary = {}) -> void:
	_write(Level.DEBUG, module, message, fields)


func info(module: String, message: String, fields: Dictionary = {}) -> void:
	_write(Level.INFO, module, message, fields)


func warn(module: String, message: String, fields: Dictionary = {}) -> void:
	_write(Level.WARN, module, message, fields)


func error(module: String, message: String, fields: Dictionary = {}) -> void:
	_write(Level.ERROR, module, message, fields)


func _write(level: int, module: String, message: String, fields: Dictionary) -> void:
	if level < min_level:
		return
	var line := "%s %s %s: %s" % [_level_tag(level), Time.get_datetime_string_from_system(true), module, message]
	for k in fields.keys():
		line += " %s=%s" % [k, str(fields[k])]
	printerr(line)
	log_emitted.emit(level, module, message, fields)


func _level_tag(level: int) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO:  return "INFO "
		Level.WARN:  return "WARN "
		Level.ERROR: return "ERROR"
		_: return "?    "
