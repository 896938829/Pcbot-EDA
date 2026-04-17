class_name SchNet
extends Resource

## 原理图电气网络。

@export var id: String = ""
@export var name: String = ""
@export var pins: Array = []        ## ["U1.3", "R1.2"] -> <placement_ref>.<pin_number>
@export var class_type: String = "" ## POWER / GND / SIGNAL / etc


func to_dict() -> Dictionary:
	var sorted_pins: Array = pins.duplicate()
	sorted_pins.sort()
	return {
		"id": id,
		"name": name,
		"pins": sorted_pins,
		"class_type": class_type,
	}


static func from_dict(d: Dictionary) -> SchNet:
	var n := SchNet.new()
	n.id = d.get("id", "")
	n.name = d.get("name", "")
	n.pins = d.get("pins", [])
	n.class_type = d.get("class_type", "")
	return n


func has_pin(pin_ref: String) -> bool:
	return pins.has(pin_ref)


func add_pin(pin_ref: String) -> bool:
	if pins.has(pin_ref):
		return false
	pins.append(pin_ref)
	return true
