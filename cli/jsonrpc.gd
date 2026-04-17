class_name JsonRpc
extends RefCounted

## JSON-RPC 2.0 构造 / 校验。单向：接收请求，返回响应。

const VERSION: String = "2.0"

enum ErrorCode {
	PARSE_ERROR = -32700,
	INVALID_REQUEST = -32600,
	METHOD_NOT_FOUND = -32601,
	INVALID_PARAMS = -32602,
	INTERNAL_ERROR = -32603,
	SERVER_ERROR = -32000,
}


static func parse_request(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"_parse_error": parser.get_error_message()}
	var data = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"_invalid": "not an object"}
	if str(data.get("jsonrpc", "")) != VERSION:
		return {"_invalid": "jsonrpc field must be '2.0'"}
	if not data.has("method"):
		return {"_invalid": "missing method"}
	return data


static func response_ok(id, result: Variant) -> Dictionary:
	return {"jsonrpc": VERSION, "id": id, "result": result}


static func response_err(id, code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"code": code, "message": message}
	if data != null:
		err["data"] = data
	return {"jsonrpc": VERSION, "id": id, "error": err}


static func result_to_rpc(id, result: Result) -> Dictionary:
	if result.ok:
		var payload: Dictionary = result.data.duplicate()
		payload["warnings"] = result.warnings
		payload["touched_files"] = result.touched_files
		return response_ok(id, payload)
	var err_code: int = ErrorCode.SERVER_ERROR
	match result.code:
		1: err_code = ErrorCode.INVALID_PARAMS
		2: err_code = ErrorCode.INTERNAL_ERROR
		3: err_code = ErrorCode.SERVER_ERROR
	return response_err(id, err_code, result.message, {
		"pcbot_code": result.code,
		"errors": result.errors,
		"warnings": result.warnings,
	})
