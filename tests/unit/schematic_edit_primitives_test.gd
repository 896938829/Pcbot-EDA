class_name SchematicEditPrimitivesTest
extends RefCounted

## M1.2 P9/P10/P12 CLI：move_placement / remove_placement / remove_net / disconnect_pin。


static func _make(path: String) -> void:
	var s := Schematic.new()
	s.id = "edit_prim"
	s.pages = [{"id": "p1", "name": "Main", "size_nm": [100_000_000, 100_000_000]}]
	s.placements = [
		{"uid": "pl1", "page_id": "p1", "component_ref": "R", "reference": "R1",
		 "pos_nm": [0, 0], "rotation_deg": 0, "mirror": false},
		{"uid": "pl2", "page_id": "p1", "component_ref": "R", "reference": "R2",
		 "pos_nm": [10_000_000, 0], "rotation_deg": 0, "mirror": false},
		{"uid": "pl3", "page_id": "p1", "component_ref": "C", "reference": "C1",
		 "pos_nm": [20_000_000, 0], "rotation_deg": 0, "mirror": false},
	]
	s.nets = [
		{"id": "N1", "name": "NET_A", "pins": ["R1.1", "R2.1"], "class_type": ""},
		{"id": "N2", "name": "NET_B", "pins": ["R2.2", "C1.1", "R1.2"], "class_type": ""},
	]
	JsonStable.write_file(path, s.to_dict())


static func _reg() -> CommandRegistry:
	var r := CommandRegistry.new()
	SchematicCommands.register(r)
	return r


static func _load_s(path: String) -> Schematic:
	var d = JsonStable.read_file(path)
	return Schematic.from_dict(d)


static func run() -> Array:
	var r: Array = []
	var abs := ProjectSettings.globalize_path("user://p9_edit_prim.sch.json")

	r.append(Assert.case("move_placement: pos 更新", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.move_placement",
			{"path": abs, "placement_uid": "pl1", "pos_nm": [5_000_000, 3_000_000]}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		var s := _load_s(abs)
		var pos: Array = s.find_placement("pl1").get("pos_nm", [])
		return Assert.eq("%d,%d" % [int(pos[0]), int(pos[1])], "5000000,3000000")))

	r.append(Assert.case("move_placement: 未知 uid 拒绝", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.move_placement",
			{"path": abs, "placement_uid": "plX", "pos_nm": [0, 0]}
		)
		return Assert.eq(res.ok, false)))

	r.append(Assert.case("remove_placement: 删 pl1 连带 N1（pins<2）删除", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.remove_placement",
			{"path": abs, "placement_uid": "pl1"}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		var s := _load_s(abs)
		if not s.find_placement("pl1").is_empty():
			return "pl1 not removed"
		if not s.find_net("N1").is_empty():
			return "N1 should be removed (only R2.1 left)"
		var n2: Dictionary = s.find_net("N2")
		if n2.is_empty():
			return "N2 missing"
		var pins: Array = n2.get("pins", [])
		if pins.has("R1.2"):
			return "R1.2 should be removed from N2"
		return ""))

	r.append(Assert.case("remove_net: 直接删 N1", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.remove_net", {"path": abs, "net_id": "N1"}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		var s := _load_s(abs)
		return Assert.eq(s.find_net("N1").is_empty(), true)))

	r.append(Assert.case("remove_net: 未知 net_id 拒绝", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.remove_net", {"path": abs, "net_id": "N99"}
		)
		return Assert.eq(res.ok, false)))

	r.append(Assert.case("disconnect_pin: N2 去掉 C1.1 → N2 仍存在", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.disconnect_pin", {"path": abs, "pin": "C1.1"}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		var s := _load_s(abs)
		var n2: Dictionary = s.find_net("N2")
		if n2.is_empty():
			return "N2 missing"
		var pins: Array = n2.get("pins", [])
		if pins.has("C1.1"):
			return "C1.1 should be removed"
		return Assert.eq(pins.size() >= 2, true)))

	r.append(Assert.case("disconnect_pin: N1 去掉 R1.1 → N1 被删（pins<2）", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.disconnect_pin", {"path": abs, "pin": "R1.1"}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		var s := _load_s(abs)
		return Assert.eq(s.find_net("N1").is_empty(), true)))

	return r
