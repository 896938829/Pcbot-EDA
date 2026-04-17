class_name JsonStable
extends RefCounted

## 稳定 JSON 序列化：键字典序、2 空格缩进、LF、末尾换行。
## round-trip 保证：stringify(parse(stringify(x))) == stringify(x)。

const INDENT: String = "  "


static func stringify(value) -> String:
	var out := _encode(value, "")
	return out + "\n"


static func parse(text: String) -> Variant:
	var parser := JSON.new()
	var code: int = parser.parse(text)
	if code != OK:
		push_error("JsonStable.parse: %s at line %d" % [parser.get_error_message(), parser.get_error_line()])
		return null
	return parser.data


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


static func read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return parse(text)


static func _encode(value, indent: String) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			if value == floor(value) and abs(value) < 1e15:
				return "%d" % int(value)
			return str(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return _encode_string(value)
		TYPE_ARRAY:
			return _encode_array(value, indent)
		TYPE_DICTIONARY:
			return _encode_dict(value, indent)
		TYPE_VECTOR2I:
			return _encode_array([value.x, value.y], indent)
		TYPE_VECTOR2:
			return _encode_array([value.x, value.y], indent)
		_:
			return _encode_string(str(value))


static func _encode_string(s: String) -> String:
	var out := "\""
	for i in s.length():
		var c := s[i]
		match c:
			"\"": out += "\\\""
			"\\": out += "\\\\"
			"\n": out += "\\n"
			"\r": out += "\\r"
			"\t": out += "\\t"
			"\b": out += "\\b"
			"\f": out += "\\f"
			_:
				var code: int = c.unicode_at(0)
				if code < 0x20:
					out += "\\u%04x" % code
				else:
					out += c
	out += "\""
	return out


static func _encode_array(arr: Array, indent: String) -> String:
	if arr.is_empty():
		return "[]"
	var child_indent := indent + INDENT
	var parts: Array[String] = []
	for v in arr:
		parts.append(child_indent + _encode(v, child_indent))
	return "[\n" + ",\n".join(parts) + "\n" + indent + "]"


static func _encode_dict(d: Dictionary, indent: String) -> String:
	if d.is_empty():
		return "{}"
	var keys: Array = d.keys().duplicate()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	var child_indent := indent + INDENT
	var parts: Array[String] = []
	for k in keys:
		var line := child_indent + _encode_string(str(k)) + ": " + _encode(d[k], child_indent)
		parts.append(line)
	return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
