class_name Result
extends RefCounted

## 结构化调用结果。CLI / 服务层以此为返回类型。

var ok: bool = true
var code: int = 0  ## PcbotError.Code
var message: String = ""
var data: Dictionary = {}
var errors: Array = []         ## [{code, rule?, ref?, msg}, ...]
var warnings: Array = []
var touched_files: Array = []  ## 本次调用写入的文件路径


static func success(data: Dictionary = {}) -> Result:
	var r := Result.new()
	r.ok = true
	r.code = 0
	r.data = data
	return r


static func err(code: int, message: String, extra: Dictionary = {}) -> Result:
	var r := Result.new()
	r.ok = false
	r.code = code
	r.message = message
	r.errors.append({
		"code": _code_name(code),
		"msg": message,
		"data": extra,
	})
	return r


static func rule_violation(rule_id: String, ref: String, msg: String) -> Result:
	var r := Result.new()
	r.ok = false
	r.code = 3
	r.message = msg
	r.errors.append({
		"code": "RULE_VIOLATION",
		"rule": rule_id,
		"ref": ref,
		"msg": msg,
	})
	return r


func add_touched(path: String) -> void:
	if not touched_files.has(path):
		touched_files.append(path)


func add_warning(rule_id: String, ref: String, msg: String) -> void:
	warnings.append({"rule": rule_id, "ref": ref, "msg": msg})


func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"code": code,
		"message": message,
		"data": data,
		"errors": errors,
		"warnings": warnings,
		"touched_files": touched_files,
	}


static func _code_name(code: int) -> String:
	match code:
		0: return "OK"
		1: return "USER_ERROR"
		2: return "SYSTEM_ERROR"
		3: return "RULE_VIOLATION"
		_: return "UNKNOWN"
