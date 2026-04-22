class_name UndoStackTest
extends RefCounted

## UndoStack 单元覆盖。基于 schematic.move_placement 做 forward/inverse round-trip。


static func _make(path: String) -> void:
	var s := Schematic.new()
	s.id = "undo_test"
	s.pages = [{"id": "p1", "name": "Main", "size_nm": [100_000_000, 100_000_000]}]
	s.placements = [{
		"uid": "pl1", "page_id": "p1", "component_ref": "R", "reference": "R1",
		"pos_nm": [0, 0], "rotation_deg": 0, "mirror": false,
	}]
	JsonStable.write_file(path, s.to_dict())


static func _pos(path: String, uid: String) -> Array:
	var d = JsonStable.read_file(path)
	var s := Schematic.from_dict(d)
	return s.find_placement(uid).get("pos_nm", [])


static func run() -> Array:
	var r: Array = []
	var abs := ProjectSettings.globalize_path("user://undo_stack_test.sch.json")

	r.append(Assert.case("undo 空栈返回 false", func():
		var u := UndoStack.new()
		return Assert.eq(u.undo(), false)))

	r.append(Assert.case("push + undo + redo roundtrip (move)", func():
		_make(abs)
		var u := UndoStack.new()
		var reg := CommandRegistry.new()
		SchematicCommands.register(reg)
		var forward := {"method": "schematic.move_placement",
						"params": {"path": abs, "placement_uid": "pl1", "pos_nm": [5_000_000, 0]}}
		var inverse := {"method": "schematic.move_placement",
						"params": {"path": abs, "placement_uid": "pl1", "pos_nm": [0, 0]}}
		reg.call_method(forward.method, forward.params)
		u.push({"forward": [forward], "inverse": [inverse]})
		var p1 := _pos(abs, "pl1")
		if int(p1[0]) != 5_000_000:
			return "forward 未生效: %s" % str(p1)
		if not u.undo():
			return "undo 失败"
		var p2 := _pos(abs, "pl1")
		if int(p2[0]) != 0:
			return "undo 未回退: %s" % str(p2)
		if not u.redo():
			return "redo 失败"
		var p3 := _pos(abs, "pl1")
		return Assert.eq(int(p3[0]), 5_000_000)))

	r.append(Assert.case("push 清空 redo 栈", func():
		_make(abs)
		var u := UndoStack.new()
		var f := {"method": "schematic.move_placement",
				  "params": {"path": abs, "placement_uid": "pl1", "pos_nm": [1, 0]}}
		var i := {"method": "schematic.move_placement",
				  "params": {"path": abs, "placement_uid": "pl1", "pos_nm": [0, 0]}}
		u.push({"forward": [f], "inverse": [i]})
		u.undo()
		## 新 push 应清空 redo
		u.push({"forward": [f], "inverse": [i]})
		return Assert.eq(u.redo_size(), 0)))

	r.append(Assert.case("clear 清空 undo+redo", func():
		var u := UndoStack.new()
		var f := {"method": "x", "params": {}}
		u.push({"forward": [f], "inverse": [f]})
		u.clear()
		return Assert.eq(u.can_undo(), false)))

	return r
