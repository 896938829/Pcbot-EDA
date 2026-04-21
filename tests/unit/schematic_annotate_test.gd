class_name SchematicAnnotateTest
extends RefCounted

## P8：annotate 规则补全测试。覆盖混合命名 / start_at / 占用跳过 / 多前缀。


static func _make(path: String, refs: Array) -> void:
	var s := Schematic.new()
	s.id = "annot_test"
	s.pages = [{"id": "p1", "name": "Main", "size_nm": [100_000_000, 100_000_000]}]
	for i in refs.size():
		s.placements.append({
			"uid": "pl%d" % (i + 1),
			"page_id": "p1",
			"component_id": "X",
			"reference": str(refs[i]),
			"pos_nm": [0, 0],
			"rot_deg": 0,
			"mirror": false,
		})
	JsonStable.write_file(path, s.to_dict())


static func _refs_after(path: String, params: Dictionary) -> Array:
	params["path"] = path
	var res := SchematicCommands._annotate(params)
	if not res.ok:
		return ["ERR:" + str(res.error.get("msg", ""))]
	var s := Schematic.from_dict(JsonStable.read_file(path))
	var out: Array = []
	for pl in s.placements:
		out.append(str(pl.get("reference", "")))
	out.sort()
	return out


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("mixed_named_and_unnamed", func():
		var p := "user://annot_mixed.sch.json"
		_make(p, ["R1", "R3", "R?", "R?"])
		var got := _refs_after(p, {})
		var want := ["R1", "R2", "R3", "R4"]
		return Assert.eq(got, want)))

	r.append(Assert.case("start_at_jumps_gap", func():
		var p := "user://annot_jump.sch.json"
		_make(p, ["U1", "U?"])
		var got := _refs_after(p, {"start_at": {"U": 200}})
		var want := ["U1", "U200"]
		return Assert.eq(got, want)))

	r.append(Assert.case("start_at_respects_used", func():
		var p := "user://annot_used.sch.json"
		_make(p, ["R100", "R?"])
		var got := _refs_after(p, {"start_at": {"R": 100}})
		var want := ["R100", "R101"]
		return Assert.eq(got, want)))

	r.append(Assert.case("independent_prefix_buckets", func():
		var p := "user://annot_buckets.sch.json"
		_make(p, ["R?", "C?", "U?"])
		var got := _refs_after(p, {})
		var want := ["C1", "R1", "U1"]
		return Assert.eq(got, want)))

	r.append(Assert.case("idempotent_second_run", func():
		var p := "user://annot_idem.sch.json"
		_make(p, ["R?", "R?"])
		_refs_after(p, {})
		var got := _refs_after(p, {})
		var want := ["R1", "R2"]
		return Assert.eq(got, want)))
	return r
