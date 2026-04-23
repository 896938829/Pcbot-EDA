class_name CliConsole
extends VBoxContainer

## CLI 调试面板（M1.2 P6）。
## - 顶部 LineEdit 单行 JSON-RPC 输入 + Send 按钮
## - 中部 RichTextLabel 历史（请求 + 响应）
## - 历史持久化 user://cli_history.jsonl（最近 100 条）
## - Up/Down 方向键调取历史
## - 复用 CommandRegistry 同进程调用，走与 CLI 相同的方法注册（ADR-0005）

const HISTORY_MAX: int = 100
const HISTORY_FILE := "user://cli_history.jsonl"

var _input: LineEdit
var _send_btn: Button
var _history_view: RichTextLabel

var _history: Array = []          ## [{request, response, ts}]
var _history_index: int = -1      ## 当前 Up/Down 指针
var _registry: CommandRegistry


func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)

	_input = LineEdit.new()
	_input.placeholder_text = '{"jsonrpc":"2.0","id":1,"method":"schematic.new","params":{"path":"..."}}'
	_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_input.text_submitted.connect(_on_submit)
	_input.gui_input.connect(_on_input_key)
	row.add_child(_input)

	_send_btn = Button.new()
	_send_btn.text = "发送"
	_send_btn.pressed.connect(func(): _on_submit(_input.text))
	row.add_child(_send_btn)

	_history_view = RichTextLabel.new()
	_history_view.bbcode_enabled = true
	_history_view.scroll_following = true
	_history_view.size_flags_vertical = SIZE_EXPAND_FILL
	_history_view.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_history_view)

	_build_registry()
	_load_history()


func _build_registry() -> void:
	_registry = CommandRegistry.new()
	ProjectCommands.register(_registry)
	SymbolCommands.register(_registry)
	LibraryCommands.register(_registry)
	SchematicCommands.register(_registry)
	CheckCommands.register(_registry)
	SkillsCommands.register(_registry)
	RunCommands.register(_registry)


func _on_submit(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return
	var parsed = JSON.parse_string(trimmed)
	if typeof(parsed) != TYPE_DICTIONARY:
		_render_entry(trimmed, {"error": "parse_error: not a JSON object"})
		return
	var method := str(parsed.get("method", ""))
	var params: Dictionary = parsed.get("params", {}) if typeof(parsed.get("params", {})) == TYPE_DICTIONARY else {}
	if method == "":
		_render_entry(trimmed, {"error": "missing 'method'"})
		return
	if not _registry.has(method):
		_render_entry(trimmed, {"error": "method not found: %s" % method, "available": _registry.list_methods()})
		return
	var result: Result = _registry.call_method(method, params)
	var resp := {
		"ok": result.ok,
		"code": result.code,
		"message": result.message,
		"data": result.data,
	}
	_render_entry(trimmed, resp)
	_push_history(trimmed, resp)
	_input.text = ""
	_history_index = -1


## RichTextLabel 的 append_text 会解析 [xxx] 为 bbcode。JSON 里的 []
## 会把响应渲染成空白 tag，颜色 tag 之后的内容也被吃掉。转义后再塞入。
static func _bbcode_escape(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")


func _render_entry(req_text: String, resp: Dictionary) -> void:
	var ts := Time.get_datetime_string_from_system(true)
	_history_view.append_text("[color=#6699ff][%s] ▶[/color] %s\n" % [ts, _bbcode_escape(req_text)])
	var ok := bool(resp.get("ok", false)) and not resp.has("error")
	var color := "#60d060" if ok else "#e05050"
	_history_view.append_text("[color=%s]◀[/color] %s\n\n" % [color, _bbcode_escape(JSON.stringify(resp))])


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var k := event as InputEventKey
	if k.keycode == KEY_UP:
		if _history.is_empty():
			return
		if _history_index < 0:
			_history_index = _history.size() - 1
		else:
			_history_index = max(0, _history_index - 1)
		_input.text = str(_history[_history_index].get("request", ""))
		_input.caret_column = _input.text.length()
	elif k.keycode == KEY_DOWN:
		if _history.is_empty() or _history_index < 0:
			return
		_history_index += 1
		if _history_index >= _history.size():
			_history_index = -1
			_input.text = ""
		else:
			_input.text = str(_history[_history_index].get("request", ""))
			_input.caret_column = _input.text.length()


func _push_history(req: String, resp: Dictionary) -> void:
	_history.append({"request": req, "response": resp, "ts": Time.get_datetime_string_from_system(true)})
	while _history.size() > HISTORY_MAX:
		_history.pop_front()
	_save_history()


func _load_history() -> void:
	_history.clear()
	if not FileAccess.file_exists(HISTORY_FILE):
		return
	var f := FileAccess.open(HISTORY_FILE, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var d = JSON.parse_string(line)
		if typeof(d) == TYPE_DICTIONARY:
			_history.append(d)
	f.close()


func _save_history() -> void:
	var f := FileAccess.open(HISTORY_FILE, FileAccess.WRITE)
	if f == null:
		return
	for e in _history:
		f.store_line(JSON.stringify(e))
	f.close()
