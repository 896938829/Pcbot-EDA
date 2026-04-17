class_name Schematic
extends Resource

## 原理图：多页面 + 元件实例 + 电气网络。

const FORMAT_VERSION: int = 1

@export var id: String = ""
@export var pages: Array = []          ## [{id:String, name:String, size_nm:[int,int]}]
@export var placements: Array = []     ## SchPlacement.to_dict()
@export var nets: Array = []           ## SchNet.to_dict()


func to_dict() -> Dictionary:
	var sorted_pages: Array = pages.duplicate(true)
	sorted_pages.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))

	var sorted_pl: Array = placements.duplicate(true)
	sorted_pl.sort_custom(func(a, b): return str(a.get("uid", "")) < str(b.get("uid", "")))

	var sorted_nets: Array = nets.duplicate(true)
	sorted_nets.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))

	return {
		"format_version": FORMAT_VERSION,
		"id": id,
		"pages": sorted_pages,
		"placements": sorted_pl,
		"nets": sorted_nets,
	}


static func from_dict(d: Dictionary) -> Schematic:
	var s := Schematic.new()
	s.id = d.get("id", "")
	s.pages = d.get("pages", [])
	s.placements = d.get("placements", [])
	s.nets = d.get("nets", [])
	return s


func find_page(page_id: String) -> Dictionary:
	for p in pages:
		if str(p.get("id", "")) == page_id:
			return p
	return {}


func find_placement(uid: String) -> Dictionary:
	for pl in placements:
		if str(pl.get("uid", "")) == uid:
			return pl
	return {}


func find_placement_by_ref(reference: String) -> Dictionary:
	for pl in placements:
		if str(pl.get("reference", "")) == reference:
			return pl
	return {}


func find_net(net_id: String) -> Dictionary:
	for n in nets:
		if str(n.get("id", "")) == net_id:
			return n
	return {}


func find_net_by_name(name: String) -> Dictionary:
	for n in nets:
		if str(n.get("name", "")) == name:
			return n
	return {}


func next_net_id() -> String:
	var max_n: int = 0
	for n in nets:
		var id_s: String = str(n.get("id", ""))
		if id_s.begins_with("N"):
			var num: int = int(id_s.substr(1))
			if num > max_n:
				max_n = num
	return "N%d" % (max_n + 1)


func next_placement_uid() -> String:
	var max_n: int = 0
	for pl in placements:
		var uid: String = str(pl.get("uid", ""))
		if uid.begins_with("pl"):
			var num: int = int(uid.substr(2))
			if num > max_n:
				max_n = num
	return "pl%d" % (max_n + 1)
