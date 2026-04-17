class_name PcbotError
extends RefCounted

## 错误码 + 结构化 Result。跨模块错误边界统一走 Result。

enum Code {
	OK = 0,
	USER_ERROR = 1,          ## 参数非法、引用不存在
	SYSTEM_ERROR = 2,        ## I/O 失败、引擎异常
	RULE_VIOLATION = 3,      ## DRC / ERC 违例
}


static func code_to_exit(code: int) -> int:
	match code:
		Code.OK: return 0
		Code.USER_ERROR: return 1
		Code.SYSTEM_ERROR: return 2
		Code.RULE_VIOLATION: return 3
		_: return 2


static func code_to_name(code: int) -> String:
	match code:
		Code.OK: return "OK"
		Code.USER_ERROR: return "USER_ERROR"
		Code.SYSTEM_ERROR: return "SYSTEM_ERROR"
		Code.RULE_VIOLATION: return "RULE_VIOLATION"
		_: return "UNKNOWN"
