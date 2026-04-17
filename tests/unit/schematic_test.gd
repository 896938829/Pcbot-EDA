class_name SchematicTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("next_net_id increments", func():
		var s := Schematic.new()
		s.nets = [{"id": "N1", "name": "a", "pins": []}, {"id": "N3", "name": "b", "pins": []}]
		return Assert.eq(s.next_net_id(), "N4")))
	r.append(Assert.case("next_placement_uid empty -> pl1", func():
		var s := Schematic.new()
		return Assert.eq(s.next_placement_uid(), "pl1")))
	r.append(Assert.case("find_placement_by_ref", func():
		var s := Schematic.new()
		s.placements = [{"uid": "pl1", "reference": "R1"}]
		return Assert.eq(s.find_placement_by_ref("R1").get("uid", ""), "pl1")))
	r.append(Assert.case("serialisation sorts nets", func():
		var s := Schematic.new()
		s.nets = [{"id": "N2", "name": "z", "pins": []}, {"id": "N1", "name": "a", "pins": []}]
		var d := s.to_dict()
		var ns: Array = d["nets"]
		return Assert.eq(str(ns[0]["id"]), "N1")))
	return r
