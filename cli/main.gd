extends SceneTree

## headless CLI 入口。
## 运行：godot --headless -s cli/main.gd -- '{"jsonrpc":"2.0","id":1,"method":"project.new","params":{...}}'
## 或从 stdin 读一行 JSON-RPC。


func _init() -> void:
	var registry := CommandRegistry.new()
	_register_all(registry)

	var input := _read_request_text()
	if input.strip_edges() == "":
		_emit_help(registry)
		quit(1)
		return

	var req := JsonRpc.parse_request(input)
	if req.has("_parse_error"):
		var r := JsonRpc.response_err(null, JsonRpc.ErrorCode.PARSE_ERROR, req["_parse_error"])
		print(JSON.stringify(r))
		quit(1)
		return
	if req.has("_invalid"):
		var r2 := JsonRpc.response_err(null, JsonRpc.ErrorCode.INVALID_REQUEST, req["_invalid"])
		print(JSON.stringify(r2))
		quit(1)
		return

	var method: String = str(req.get("method", ""))
	var params: Dictionary = req.get("params", {}) if typeof(req.get("params", {})) == TYPE_DICTIONARY else {}
	var id = req.get("id", null)

	if not registry.has(method):
		var r3 := JsonRpc.response_err(id, JsonRpc.ErrorCode.METHOD_NOT_FOUND, "method not found: %s" % method)
		print(JSON.stringify(r3))
		_write_run_report(params, method, Result.err(1, "method not found"))
		quit(1)
		return

	var result: Result = registry.call_method(method, params)
	var rpc := JsonRpc.result_to_rpc(id, result)
	print(JSON.stringify(rpc))

	_write_run_report(params, method, result)

	var exit_code: int = PcbotError.code_to_exit(result.code)
	quit(exit_code)


func _register_all(registry: CommandRegistry) -> void:
	ProjectCommands.register(registry)
	SymbolCommands.register(registry)
	LibraryCommands.register(registry)
	SchematicCommands.register(registry)
	CheckCommands.register(registry)
	SkillsCommands.register(registry)
	RunCommands.register(registry)


func _read_request_text() -> String:
	## 优先级：argv inline JSON（args[0] 非 "--input"）> --input <file> > stdin。
	## --input 用于在子进程测试中绕开 stdin 在 Windows headless 下的不可靠性。
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and str(args[0]) != "--input":
		return str(args[0])
	for i in args.size():
		if str(args[i]) == "--input" and i + 1 < args.size():
			var fpath: String = str(args[i + 1])
			var f := FileAccess.open(fpath, FileAccess.READ)
			if f == null:
				return ""
			return f.get_as_text()
	var line := OS.read_string_from_stdin()
	return line


func _write_run_report(params: Dictionary, method: String, result: Result) -> void:
	var project_root: String = str(params.get("project_root", ""))
	if project_root == "":
		var path: String = str(params.get("path", ""))
		if path != "":
			project_root = path.get_base_dir()
	if project_root == "":
		var sch: String = str(params.get("schematic", ""))
		if sch != "":
			project_root = sch.get_base_dir()
	if project_root == "":
		return
	RunReport.write(ProjectFs.normalize(project_root), method, params, result)


func _emit_help(registry: CommandRegistry) -> void:
	var help := {
		"jsonrpc": "2.0",
		"error": {
			"code": JsonRpc.ErrorCode.INVALID_REQUEST,
			"message": "no request on stdin or argv",
			"data": {"methods": registry.list_methods()},
		},
	}
	print(JSON.stringify(help))
