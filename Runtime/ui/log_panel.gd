class_name LogPanel
extends VBoxContainer

## 日志面板（M1.2 P5）。
## - Tab 1 Logger：订阅 Logger.log_emitted，RichTextLabel 按 level 着色
## - Tab 2 Diagnostics：轮询 .pcbot/diagnostics.jsonl（mtime 变化）列未解决违例
## - Tab 3 Last Run：读 .pcbot/last-run.json 展示

const POLL_SEC: float = 1.0

var _tabs: TabContainer
var _logger_view: RichTextLabel
var _diag_view: RichTextLabel
var _last_run_view: RichTextLabel

var _project_root: String = ""
var _diag_mtime: int = 0
var _last_run_mtime: int = 0
var _timer: Timer


func _ready() -> void:
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_tabs)

	_logger_view = _make_rtl("Logger")
	_diag_view = _make_rtl("Diagnostics")
	_last_run_view = _make_rtl("Last Run")

	if Engine.has_singleton("Logger") or get_node_or_null("/root/Logger") != null:
		var logger := get_node("/root/Logger")
		logger.log_emitted.connect(_on_log_emitted)

	_timer = Timer.new()
	_timer.wait_time = POLL_SEC
	_timer.one_shot = false
	_timer.autostart = true
	_timer.timeout.connect(_poll_pcbot_files)
	add_child(_timer)


func _make_rtl(tab_name: String) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.name = tab_name
	rtl.bbcode_enabled = true
	rtl.fit_content = false
	rtl.scroll_following = true
	rtl.size_flags_vertical = SIZE_EXPAND_FILL
	rtl.size_flags_horizontal = SIZE_EXPAND_FILL
	_tabs.add_child(rtl)
	return rtl


## 由主窗口调用，通知工程目录（.pcbot 所在）。
func set_project_root(root: String) -> void:
	_project_root = root
	_diag_mtime = 0
	_last_run_mtime = 0
	_poll_pcbot_files()


func _on_log_emitted(level: int, module: String, message: String, fields: Dictionary) -> void:
	if _logger_view == null:
		return
	var color := _color_for_level(level)
	var tag := _tag_for_level(level)
	var line := "[color=%s]%s %s:[/color] %s" % [color, tag, module, message]
	if not fields.is_empty():
		var extras: Array[String] = []
		for k in fields.keys():
			extras.append("%s=%s" % [k, str(fields[k])])
		line += " [color=#888888](%s)[/color]" % ", ".join(extras)
	_logger_view.append_text(line + "\n")


func _color_for_level(level: int) -> String:
	match level:
		0: return "#888888"  ## DEBUG
		1: return "#e0e0e0"  ## INFO
		2: return "#e0c050"  ## WARN
		3: return "#e05050"  ## ERROR
		_: return "#808080"


func _tag_for_level(level: int) -> String:
	match level:
		0: return "DEBUG"
		1: return "INFO "
		2: return "WARN "
		3: return "ERROR"
		_: return "?    "


func _poll_pcbot_files() -> void:
	if _project_root == "":
		return
	var diag_path: String = _project_root.path_join(".pcbot/diagnostics.jsonl")
	var last_path: String = _project_root.path_join(".pcbot/last-run.json")
	if FileAccess.file_exists(diag_path):
		var m := FileAccess.get_modified_time(diag_path)
		if m != _diag_mtime:
			_diag_mtime = m
			_refresh_diagnostics(diag_path)
	if FileAccess.file_exists(last_path):
		var m := FileAccess.get_modified_time(last_path)
		if m != _last_run_mtime:
			_last_run_mtime = m
			_refresh_last_run(last_path)


func _refresh_diagnostics(path: String) -> void:
	_diag_view.clear()
	var unresolved: Dictionary = {}   ## key(rule_id+ref) → record
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var parsed = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var key := "%s|%s" % [str(parsed.get("rule_id", "")), str(parsed.get("ref", ""))]
		if parsed.has("resolved_by_commit"):
			unresolved.erase(key)
		else:
			unresolved[key] = parsed
	f.close()
	if unresolved.is_empty():
		_diag_view.append_text("[color=#60d060]无未解决违例[/color]\n")
		return
	_diag_view.append_text("[color=#e0c050]未解决违例 %d 条[/color]\n\n" % unresolved.size())
	for key in unresolved.keys():
		var d: Dictionary = unresolved[key]
		_diag_view.append_text(
			"[b]%s[/b] · %s\n    %s\n\n"
			% [str(d.get("rule_id", "")), str(d.get("ref", "")), str(d.get("message", ""))]
		)


func _refresh_last_run(path: String) -> void:
	_last_run_view.clear()
	var data = JsonStable.read_file(path)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var method := str(data.get("command", ""))
	var exit_code := int(data.get("exit_code", 0))
	var color := "#60d060" if exit_code == 0 else "#e05050"
	_last_run_view.append_text("[b]%s[/b]  [color=%s]exit=%d[/color]\n" % [method, color, exit_code])
	if data.has("ts"):
		_last_run_view.append_text("ts: %s\n" % str(data["ts"]))
	if data.has("params"):
		_last_run_view.append_text("\n[color=#888888]params:[/color]\n%s\n" % JSON.stringify(data["params"], "  "))
	if data.has("errors") and (data["errors"] as Array).size() > 0:
		_last_run_view.append_text("\n[color=#e05050]errors:[/color]\n")
		for e in data["errors"]:
			_last_run_view.append_text("  · %s\n" % JSON.stringify(e))
	if data.has("touched_files") and (data["touched_files"] as Array).size() > 0:
		_last_run_view.append_text("\n[color=#888888]touched:[/color]\n")
		for f2 in data["touched_files"]:
			_last_run_view.append_text("  · %s\n" % str(f2))
