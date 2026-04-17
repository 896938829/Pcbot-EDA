class_name ProjectFs
extends RefCounted

## 工程目录抽象：按扩展名派发读写。路径统一用正斜杠。

const PCBOT_DIR: String = ".pcbot"


static func normalize(path: String) -> String:
	return path.replace("\\", "/")


static func ensure_dir(dir: String) -> Error:
	dir = normalize(dir)
	if DirAccess.dir_exists_absolute(dir):
		return OK
	return DirAccess.make_dir_recursive_absolute(dir)


static func project_root_from(path: String) -> String:
	## 从任意工程相关路径向上找 *.pcbproj。
	path = normalize(path)
	var p := path
	while p != "" and p != "/":
		if p.ends_with(".pcbproj"):
			return p.get_base_dir()
		var da := DirAccess.open(p)
		if da != null:
			for f in da.get_files():
				if f.ends_with(".pcbproj"):
					return p
		var parent := p.get_base_dir()
		if parent == p:
			break
		p = parent
	return ""


static func pcbot_dir(project_root: String) -> String:
	return normalize(project_root.path_join(PCBOT_DIR))


static func ensure_pcbot(project_root: String) -> Error:
	return ensure_dir(pcbot_dir(project_root))


static func list_files(dir: String, ext: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	while true:
		var f := da.get_next()
		if f == "":
			break
		if f.begins_with(".") or da.current_is_dir():
			continue
		if ext == "" or f.ends_with(ext):
			out.append(dir.path_join(f))
	da.list_dir_end()
	return out


static func walk_files(dir: String, ext: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	while true:
		var f := da.get_next()
		if f == "":
			break
		if f.begins_with("."):
			continue
		var full := dir.path_join(f)
		if da.current_is_dir():
			out.append_array(walk_files(full, ext))
		elif ext == "" or f.ends_with(ext):
			out.append(full)
	da.list_dir_end()
	return out
