class_name DesignProject
extends Resource

## 工程描述：聚合原理图、元件库引用、设置等。

const FORMAT_VERSION: int = 1

@export var name: String = ""
@export var schematic_refs: Array = []   ## 相对路径列表
@export var library_refs: Array = []     ## 相对路径列表
@export var pcb_ref: String = ""         ## M2+ 留空
@export var settings: Dictionary = {}


func to_dict() -> Dictionary:
	var sl: Array = schematic_refs.duplicate()
	sl.sort()
	var ll: Array = library_refs.duplicate()
	ll.sort()
	return {
		"format_version": FORMAT_VERSION,
		"name": name,
		"schematic_refs": sl,
		"library_refs": ll,
		"pcb_ref": pcb_ref,
		"settings": settings,
	}


static func from_dict(d: Dictionary) -> DesignProject:
	var p := DesignProject.new()
	p.name = d.get("name", "")
	p.schematic_refs = d.get("schematic_refs", [])
	p.library_refs = d.get("library_refs", [])
	p.pcb_ref = d.get("pcb_ref", "")
	p.settings = d.get("settings", {})
	return p
