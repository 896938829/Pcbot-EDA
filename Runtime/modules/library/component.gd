class_name LibraryComponent
extends Resource

## 元件库条目：逻辑元件（厂商、料号、参数），关联符号与封装。

const FORMAT_VERSION: int = 1

@export var id: String = ""
@export var manufacturer: String = ""
@export var part_number: String = ""
@export var description: String = ""
@export var symbol_ref: String = ""           ## *.sym.json 相对路径
@export var footprint_refs: Array = []        ## *.fp.json 相对路径（M2+）
@export var parameters: Dictionary = {}       ## {value, tolerance, package, ...}
@export var tags: Array = []


func to_dict() -> Dictionary:
	var sorted_fp: Array = footprint_refs.duplicate()
	sorted_fp.sort()
	var sorted_tags: Array = tags.duplicate()
	sorted_tags.sort()
	return {
		"format_version": FORMAT_VERSION,
		"id": id,
		"manufacturer": manufacturer,
		"part_number": part_number,
		"description": description,
		"symbol_ref": symbol_ref,
		"footprint_refs": sorted_fp,
		"parameters": parameters,
		"tags": sorted_tags,
	}


static func from_dict(d: Dictionary) -> LibraryComponent:
	var c := LibraryComponent.new()
	c.id = d.get("id", "")
	c.manufacturer = d.get("manufacturer", "")
	c.part_number = d.get("part_number", "")
	c.description = d.get("description", "")
	c.symbol_ref = d.get("symbol_ref", "")
	c.footprint_refs = d.get("footprint_refs", [])
	c.parameters = d.get("parameters", {})
	c.tags = d.get("tags", [])
	return c
