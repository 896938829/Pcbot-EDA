class_name CommandRegistry
extends RefCounted

## 命名空间.方法 -> 回调映射。回调签名：func(params: Dictionary) -> Result。

var _handlers: Dictionary = {}


func add(method: String, callback: Callable) -> void:
	_handlers[method] = callback


func has(method: String) -> bool:
	return _handlers.has(method)


func call_method(method: String, params: Dictionary) -> Result:
	if not _handlers.has(method):
		return Result.err(PcbotError.Code.USER_ERROR, "method not found: %s" % method)
	var cb: Callable = _handlers[method]
	var r = cb.call(params)
	if r is Result:
		return r
	return Result.err(PcbotError.Code.SYSTEM_ERROR, "handler returned non-Result")


func list_methods() -> Array:
	var names: Array = _handlers.keys()
	names.sort()
	return names
