class_name YamlIO
extends RefCounted

## 最小 YAML 读写：仅支持 Skills YAML 所需的子集（键值、字符串、数字、布尔、数组、嵌套字典）。
## 不支持锚点 / 别名 / 流式语法 / 多文档。

static func parse(text: String) -> Variant:
	var lines := text.split("\n")
	var index := [0]
	return _parse_block(lines, index, 0)


static func stringify(value) -> String:
	return _emit(value, 0)


static func read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return parse(text)


static func write_file(path: String, value) -> Error:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(stringify(value))
	f.close()
	return OK


static func _indent_of(line: String) -> int:
	var n := 0
	while n < line.length() and line[n] == " ":
		n += 1
	return n


static func _parse_block(lines: PackedStringArray, index: Array, base_indent: int) -> Variant:
	var result = null
	var is_list: bool = false
	var dict_result: Dictionary = {}
	var list_result: Array = []

	while index[0] < lines.size():
		var raw: String = lines[index[0]]
		var stripped := raw.strip_edges()
		if stripped == "" or stripped.begins_with("#"):
			index[0] += 1
			continue
		var cur_indent := _indent_of(raw)
		if cur_indent < base_indent:
			break

		if stripped.begins_with("- "):
			if result == null:
				result = list_result
				is_list = true
			var after := stripped.substr(2)
			index[0] += 1
			if after.strip_edges() == "":
				var child = _parse_block(lines, index, cur_indent + 2)
				list_result.append(child if child != null else {})
			elif after.find(": ") > 0 or after.ends_with(":"):
				var pair := _parse_kv(after)
				var child_dict: Dictionary = {}
				if pair["value"] == null:
					var nested = _parse_block(lines, index, cur_indent + 2)
					child_dict[pair["key"]] = nested if nested != null else null
				else:
					child_dict[pair["key"]] = pair["value"]
				while index[0] < lines.size():
					var next_raw: String = lines[index[0]]
					var next_strip := next_raw.strip_edges()
					if next_strip == "" or next_strip.begins_with("#"):
						index[0] += 1
						continue
					var ni := _indent_of(next_raw)
					if ni <= cur_indent:
						break
					if next_strip.begins_with("- "):
						break
					var kv := _parse_kv(next_strip)
					index[0] += 1
					if kv["value"] == null:
						var nested2 = _parse_block(lines, index, ni + 2)
						child_dict[kv["key"]] = nested2 if nested2 != null else null
					else:
						child_dict[kv["key"]] = kv["value"]
				list_result.append(child_dict)
			else:
				list_result.append(_parse_scalar(after))
		else:
			if result == null:
				result = dict_result
			var kv2 := _parse_kv(stripped)
			index[0] += 1
			if kv2["value"] == null:
				var nested3 = _parse_block(lines, index, cur_indent + 2)
				dict_result[kv2["key"]] = nested3 if nested3 != null else null
			else:
				dict_result[kv2["key"]] = kv2["value"]

	if result == null:
		return {}
	return result


static func _parse_kv(s: String) -> Dictionary:
	if s.ends_with(":"):
		return {"key": s.substr(0, s.length() - 1).strip_edges(), "value": null}
	var idx := s.find(": ")
	if idx < 0:
		return {"key": s.strip_edges(), "value": null}
	var key := s.substr(0, idx).strip_edges()
	var val_s := s.substr(idx + 2).strip_edges()
	return {"key": key, "value": _parse_scalar(val_s)}


static func _parse_scalar(s: String) -> Variant:
	var t := s.strip_edges()
	if t == "" or t == "~" or t == "null":
		return null
	if t == "true":
		return true
	if t == "false":
		return false
	if t.length() >= 2 and ((t.begins_with("\"") and t.ends_with("\"")) or (t.begins_with("'") and t.ends_with("'"))):
		return t.substr(1, t.length() - 2)
	if t.is_valid_int():
		return int(t)
	if t.is_valid_float():
		return float(t)
	return t


static func _emit(value, indent: int) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			return _emit_dict(value, indent)
		TYPE_ARRAY:
			return _emit_list(value, indent)
		_:
			return _emit_scalar(value) + "\n"


static func _emit_dict(d: Dictionary, indent: int) -> String:
	if d.is_empty():
		return "{}\n"
	var pad := " ".repeat(indent)
	var out := ""
	var keys: Array = d.keys().duplicate()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	for k in keys:
		var v = d[k]
		var tv := typeof(v)
		if tv == TYPE_DICTIONARY:
			if (v as Dictionary).is_empty():
				out += "%s%s: {}\n" % [pad, str(k)]
			else:
				out += "%s%s:\n" % [pad, str(k)]
				out += _emit_dict(v, indent + 2)
		elif tv == TYPE_ARRAY:
			if (v as Array).is_empty():
				out += "%s%s: []\n" % [pad, str(k)]
			else:
				out += "%s%s:\n" % [pad, str(k)]
				out += _emit_list(v, indent)
		else:
			out += "%s%s: %s\n" % [pad, str(k), _emit_scalar(v)]
	return out


static func _emit_list(arr: Array, indent: int) -> String:
	var pad := " ".repeat(indent)
	var out := ""
	for v in arr:
		var tv := typeof(v)
		if tv == TYPE_DICTIONARY:
			var keys: Array = (v as Dictionary).keys().duplicate()
			keys.sort_custom(func(a, b): return str(a) < str(b))
			var first := true
			for k in keys:
				var sub = v[k]
				var st := typeof(sub)
				if first:
					if st == TYPE_DICTIONARY or st == TYPE_ARRAY:
						out += "%s- %s:\n" % [pad, str(k)]
						out += _emit(sub, indent + 4)
					else:
						out += "%s- %s: %s\n" % [pad, str(k), _emit_scalar(sub)]
					first = false
				else:
					if st == TYPE_DICTIONARY or st == TYPE_ARRAY:
						out += "%s  %s:\n" % [pad, str(k)]
						out += _emit(sub, indent + 4)
					else:
						out += "%s  %s: %s\n" % [pad, str(k), _emit_scalar(sub)]
		elif tv == TYPE_ARRAY:
			out += "%s-\n" % pad
			out += _emit_list(v, indent + 2)
		else:
			out += "%s- %s\n" % [pad, _emit_scalar(v)]
	return out


static func _emit_scalar(v) -> String:
	match typeof(v):
		TYPE_NIL: return "null"
		TYPE_BOOL: return "true" if v else "false"
		TYPE_INT: return str(v)
		TYPE_FLOAT: return str(v)
		TYPE_STRING, TYPE_STRING_NAME:
			var s: String = str(v)
			if s == "" or s.contains(":") or s.contains("#") or s.begins_with("-") or s == "true" or s == "false" or s == "null" or s.is_valid_int() or s.is_valid_float():
				return "\"%s\"" % s.replace("\"", "\\\"")
			return s
		_: return str(v)
