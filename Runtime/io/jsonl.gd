class_name Jsonl
extends RefCounted

## JSONL 追加写 + 逐行读。用于 .pcbot/diagnostics.jsonl。


static func append(path: String, record: Dictionary) -> Error:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
	var line := JSON.stringify(record)
	f.store_string(line + "\n")
	f.close()
	return OK


static func read_all(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var parser := JSON.new()
		if parser.parse(line) == OK:
			out.append(parser.data)
	f.close()
	return out
