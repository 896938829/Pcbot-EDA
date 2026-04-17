class_name ComponentSymbol
extends Resource

## 元件符号：原理图上的图形 + 引脚定义。坐标单位 nm。

const FORMAT_VERSION: int = 1

@export var id: String = ""
@export var name: String = ""
@export var pins: Array = []            ## [{number:String, name:String, pos:[int,int], dir:String}]
@export var graphic_svg_ref: String = ""
@export var bbox_nm: Array = [0, 0, 0, 0]  ## [x0, y0, x1, y1]
@export var metadata: Dictionary = {}


func to_dict() -> Dictionary:
	var sorted_pins: Array = pins.duplicate(true)
	sorted_pins.sort_custom(func(a, b): return _pin_key(a) < _pin_key(b))
	return {
		"format_version": FORMAT_VERSION,
		"id": id,
		"name": name,
		"pins": sorted_pins,
		"graphic_svg_ref": graphic_svg_ref,
		"bbox_nm": bbox_nm,
		"metadata": metadata,
	}


static func from_dict(d: Dictionary) -> ComponentSymbol:
	var s := ComponentSymbol.new()
	s.id = d.get("id", "")
	s.name = d.get("name", "")
	s.pins = d.get("pins", [])
	s.graphic_svg_ref = d.get("graphic_svg_ref", "")
	s.bbox_nm = d.get("bbox_nm", [0, 0, 0, 0])
	s.metadata = d.get("metadata", {})
	return s


func find_pin(number: String) -> Dictionary:
	for p in pins:
		if str(p.get("number", "")) == number:
			return p
	return {}


static func _pin_key(p: Dictionary) -> String:
	var n: String = str(p.get("number", ""))
	return n.lpad(8, "0")
