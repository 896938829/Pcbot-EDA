class_name LibraryPanel
extends VBoxContainer

## 元件库面板（M1.2 P3）。
## - 顶部搜索框 → 实时过滤 Tree
## - Tree 分两组：组件 / 符号
## - 选中 → 发 item_selected(kind, id, data)
## - 支持 drag：Tree 组件行 _get_drag_data → {type:"lib_component", id, prefix}

signal item_selected(kind: String, id: String, data: Dictionary)

const TREE_GROUP_META := "group"
const TREE_ITEM_KIND := "kind"
const TREE_ITEM_ID := "id"
const TREE_ITEM_DATA := "data"

var _search: LineEdit
var _tree: Tree
var _info: Label
var _index: LibraryIndex = LibraryIndex.new()
var _lib_root: String = ""


func _ready() -> void:
	_search = LineEdit.new()
	_search.placeholder_text = "搜索（id / part_number / manufacturer / description）"
	_search.text_changed.connect(_on_search_changed)
	add_child(_search)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 1
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_tree_selected)
	_tree.set_drag_forwarding(
		Callable(self, "_tree_get_drag"),
		Callable(self, "_tree_can_drop"),
		Callable(self, "_tree_drop")
	)
	add_child(_tree)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(0, 80)
	add_child(_info)

	_rebuild_tree()


## 由主窗口在载入工程后调用。
func set_library_root(lib_root: String) -> void:
	_lib_root = lib_root
	_index = LibraryIndex.new()
	_index.load_from_root(lib_root)
	_search.text = ""
	_rebuild_tree()


func _on_search_changed(_t: String) -> void:
	_rebuild_tree()


func _rebuild_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var q: String = _search.text.to_lower()
	var comps: Array = _index.list_components()
	var syms: Array = _index.list_symbols()

	var comp_group := _tree.create_item(root)
	comp_group.set_text(0, "组件 (%d)" % comps.size())
	comp_group.set_selectable(0, false)
	comp_group.set_metadata(0, {TREE_GROUP_META: "components"})
	for c in comps:
		if q != "" and not _match(c, q):
			continue
		var it := _tree.create_item(comp_group)
		var cid: String = str(c.get("id", ""))
		var part: String = str(c.get("part_number", ""))
		var label := cid if part == "" else "%s · %s" % [cid, part]
		it.set_text(0, label)
		it.set_metadata(0, {TREE_ITEM_KIND: "component", TREE_ITEM_ID: cid, TREE_ITEM_DATA: c})

	var sym_group := _tree.create_item(root)
	sym_group.set_text(0, "符号 (%d)" % syms.size())
	sym_group.set_selectable(0, false)
	sym_group.set_metadata(0, {TREE_GROUP_META: "symbols"})
	for s in syms:
		if q != "" and not _match(s, q):
			continue
		var it := _tree.create_item(sym_group)
		var sid: String = str(s.get("id", ""))
		it.set_text(0, sid)
		it.set_metadata(0, {TREE_ITEM_KIND: "symbol", TREE_ITEM_ID: sid, TREE_ITEM_DATA: s})


func _match(d: Dictionary, q: String) -> bool:
	for k in ["id", "part_number", "manufacturer", "description", "name"]:
		if str(d.get(k, "")).to_lower().contains(q):
			return true
	return false


func _on_tree_selected() -> void:
	var it := _tree.get_selected()
	if it == null:
		return
	var meta = it.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY or not meta.has(TREE_ITEM_KIND):
		_info.text = ""
		return
	var kind: String = meta[TREE_ITEM_KIND]
	var id_s: String = meta[TREE_ITEM_ID]
	var data: Dictionary = meta[TREE_ITEM_DATA]
	_info.text = _format_info(kind, data)
	item_selected.emit(kind, id_s, data)


func _format_info(kind: String, d: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[%s] %s" % [kind, str(d.get("id", ""))])
	if d.has("part_number") and str(d["part_number"]) != "":
		lines.append("part_number: %s" % d["part_number"])
	if d.has("manufacturer") and str(d["manufacturer"]) != "":
		lines.append("manufacturer: %s" % d["manufacturer"])
	if d.has("description") and str(d["description"]) != "":
		lines.append("description: %s" % d["description"])
	if d.has("tags") and (d["tags"] as Array).size() > 0:
		lines.append("tags: %s" % ", ".join(d["tags"]))
	return "\n".join(lines)


## Drag forwarding：从 component 行拖到 SchematicView 触发放置。
func _tree_get_drag(_at: Vector2) -> Variant:
	var it := _tree.get_selected()
	if it == null:
		return null
	var meta = it.get_metadata(0)
	if typeof(meta) != TYPE_DICTIONARY or meta.get(TREE_ITEM_KIND, "") != "component":
		return null
	var id_s: String = meta[TREE_ITEM_ID]
	var data: Dictionary = meta[TREE_ITEM_DATA]
	var preview := Label.new()
	preview.text = "＋ %s" % id_s
	_tree.set_drag_preview(preview)
	return {
		"type": "lib_component",
		"id": id_s,
		"prefix": _derive_prefix(id_s, data),
	}


## LibraryPanel 自身不接收 drop。
func _tree_can_drop(_at: Vector2, _d: Variant) -> bool:
	return false


func _tree_drop(_at: Vector2, _d: Variant) -> void:
	pass


## 从 component id 推导 reference 前缀。默认取 id 首个字母段（R-10k→R, NE555→NE, LED→LED）。
func _derive_prefix(id_s: String, data: Dictionary) -> String:
	if data.has("parameters"):
		var params: Dictionary = data["parameters"]
		if params.has("prefix"):
			return str(params["prefix"])
	var out := ""
	for i in id_s.length():
		var ch: String = id_s[i]
		if ch >= "A" and ch <= "Z":
			out += ch
		else:
			break
	return out if out != "" else "U"
