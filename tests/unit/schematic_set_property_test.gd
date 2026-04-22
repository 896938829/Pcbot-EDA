class_name SchematicSetPropertyTest
extends RefCounted

## M1.2 P4：schematic.set_property / schematic.rotate_placement 单元覆盖。


static func _make(path: String) -> void:
	var s := Schematic.new()
	s.id = "test"
	s.pages = [{"id": "p1", "name": "Main", "size_nm": [100_000_000, 100_000_000]}]
	s.placements = [
		{
			"uid": "pl1",
			"page_id": "p1",
			"component_ref": "R-10k",
			"reference": "R1",
			"pos_nm": [0, 0],
			"rotation_deg": 0,
			"mirror": false,
		},
		{
			"uid": "pl2",
			"page_id": "p1",
			"component_ref": "R-10k",
			"reference": "R2",
			"pos_nm": [10_000_000, 0],
			"rotation_deg": 0,
			"mirror": false,
		},
	]
	JsonStable.write_file(path, s.to_dict())


static func _reg() -> CommandRegistry:
	var r := CommandRegistry.new()
	SchematicCommands.register(r)
	return r


static func _get_ref(path: String, uid: String) -> String:
	var d = JsonStable.read_file(path)
	var s := Schematic.from_dict(d)
	return str(s.find_placement(uid).get("reference", ""))


static func _get_rot(path: String, uid: String) -> int:
	var d = JsonStable.read_file(path)
	var s := Schematic.from_dict(d)
	return int(s.find_placement(uid).get("rotation_deg", -1))


static func _get_mirror(path: String, uid: String) -> bool:
	var d = JsonStable.read_file(path)
	var s := Schematic.from_dict(d)
	return bool(s.find_placement(uid).get("mirror", false))


static func run() -> Array:
	var r: Array = []
	var tmp := "user://p4_set_property_test.sch.json"
	var abs := ProjectSettings.globalize_path(tmp)

	r.append(Assert.case("set_property: reference rename", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.set_property",
			{"path": abs, "placement_uid": "pl1", "key": "reference", "value": "R9"}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		return Assert.eq(_get_ref(abs, "pl1"), "R9")))

	r.append(Assert.case("set_property: reference duplicate rejected", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.set_property",
			{"path": abs, "placement_uid": "pl1", "key": "reference", "value": "R2"}
		)
		return Assert.eq(res.ok, false)))

	r.append(Assert.case("set_property: mirror toggle", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.set_property",
			{"path": abs, "placement_uid": "pl1", "key": "mirror", "value": true}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		return Assert.eq(_get_mirror(abs, "pl1"), true)))

	r.append(Assert.case("set_property: key not in whitelist rejected", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.set_property",
			{"path": abs, "placement_uid": "pl1", "key": "pos_nm", "value": [1, 2]}
		)
		return Assert.eq(res.ok, false)))

	r.append(Assert.case("rotate_placement: 90 deg", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.rotate_placement",
			{"path": abs, "placement_uid": "pl1", "rotation_deg": 90}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		return Assert.eq(_get_rot(abs, "pl1"), 90)))

	r.append(Assert.case("rotate_placement: 450 normalizes to 90", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.rotate_placement",
			{"path": abs, "placement_uid": "pl1", "rotation_deg": 450}
		)
		if not res.ok:
			return "call failed: %s" % res.message
		return Assert.eq(_get_rot(abs, "pl1"), 90)))

	r.append(Assert.case("rotate_placement: 45 rejected", func():
		_make(abs)
		var res: Result = _reg().call_method(
			"schematic.rotate_placement",
			{"path": abs, "placement_uid": "pl1", "rotation_deg": 45}
		)
		return Assert.eq(res.ok, false)))

	return r
