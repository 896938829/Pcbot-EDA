class_name SchPlacement
extends Resource

## 原理图上的元件实例。

@export var uid: String = ""
@export var page_id: String = ""
@export var component_ref: String = ""  ## 元件库 id
@export var reference: String = ""      ## e.g. "U1", "R3"
@export var pos_nm: Array = [0, 0]      ## [x, y]
@export var rotation_deg: int = 0
@export var mirror: bool = false


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"page_id": page_id,
		"component_ref": component_ref,
		"reference": reference,
		"pos_nm": pos_nm,
		"rotation_deg": rotation_deg,
		"mirror": mirror,
	}


static func from_dict(d: Dictionary) -> SchPlacement:
	var p := SchPlacement.new()
	p.uid = d.get("uid", "")
	p.page_id = d.get("page_id", "")
	p.component_ref = d.get("component_ref", "")
	p.reference = d.get("reference", "")
	p.pos_nm = d.get("pos_nm", [0, 0])
	p.rotation_deg = d.get("rotation_deg", 0)
	p.mirror = d.get("mirror", false)
	return p
