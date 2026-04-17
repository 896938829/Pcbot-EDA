class_name LibraryIndex
extends RefCounted

## 元件库索引。M1 用 JSON 扫描 + 内存索引。
## 未来（M1.x / M2）下沉为 SQLite：接口保持稳定。


var _components: Array = []   ## LibraryComponent.to_dict()
var _symbols: Array = []      ## ComponentSymbol.to_dict()
var _lib_root: String = ""


func load_from_root(lib_root: String) -> int:
	_lib_root = ProjectFs.normalize(lib_root)
	_components.clear()
	_symbols.clear()
	if not DirAccess.dir_exists_absolute(_lib_root):
		return 0
	for f in ProjectFs.walk_files(_lib_root, ".sym.json"):
		var d = JsonStable.read_file(f)
		if d != null:
			_symbols.append(d)
	for f in ProjectFs.walk_files(_lib_root, ".comp.json"):
		var d = JsonStable.read_file(f)
		if d != null:
			_components.append(d)
	return _components.size() + _symbols.size()


func list_components() -> Array:
	var out := _components.duplicate(true)
	out.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return out


func list_symbols() -> Array:
	var out := _symbols.duplicate(true)
	out.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return out


func get_component(id: String) -> Dictionary:
	for c in _components:
		if str(c.get("id", "")) == id:
			return c
	return {}


func get_symbol(id: String) -> Dictionary:
	for s in _symbols:
		if str(s.get("id", "")) == id:
			return s
	return {}


func search(query: String, field: String = "") -> Array:
	query = query.to_lower()
	var out: Array = []
	for c in _components:
		var hit := false
		if field == "" or field == "part_number":
			hit = hit or str(c.get("part_number", "")).to_lower().contains(query)
		if field == "" or field == "manufacturer":
			hit = hit or str(c.get("manufacturer", "")).to_lower().contains(query)
		if field == "" or field == "id":
			hit = hit or str(c.get("id", "")).to_lower().contains(query)
		if field == "" or field == "description":
			hit = hit or str(c.get("description", "")).to_lower().contains(query)
		if hit:
			out.append(c)
	return out
