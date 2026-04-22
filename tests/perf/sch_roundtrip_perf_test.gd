class_name SchRoundtripPerfTest
extends RefCounted

## P5：schematic round-trip 性能 + 字节稳定性。架构 §10：1k 元件 < 200 ms。


static func _ms(fn: Callable) -> int:
	var t0 := Time.get_ticks_msec()
	fn.call()
	return Time.get_ticks_msec() - t0


static func _make(n_pl: int, n_nets: int) -> Schematic:
	var s := Schematic.new()
	s.id = "perf_roundtrip"
	s.pages = [{"id": "p1", "name": "Main", "size_nm": [297_000_000, 210_000_000]}]
	for i in n_pl:
		s.placements.append({
			"uid": "pl%d" % (i + 1),
			"page_id": "p1",
			"component_id": "COMP%05d" % (i % 200),
			"reference": "R%d" % (i + 1),
			"pos_nm": [(i % 50) * 5_000_000, (i / 50) * 5_000_000],
			"rot_deg": 0,
			"mirror": false,
		})
	for i in n_nets:
		var pin_count: int = 2 + (i % 4)
		var pins: Array = []
		for k in pin_count:
			pins.append("R%d.%d" % [(i + k) % n_pl + 1, k + 1])
		s.nets.append({"id": "N%d" % (i + 1), "name": "net_%d" % i, "pins": pins})
	return s


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("sch_1k_roundtrip_byte_stable", func():
		var path := "user://perf_sch_1k.sch.json"
		var s := _make(1000, 5000)
		var w1_ms := _ms(func(): JsonStable.write_file(path, s.to_dict()))
		var bytes1 := FileAccess.get_file_as_bytes(path)
		var d = JsonStable.read_file(path)
		var s2 := Schematic.from_dict(d)
		var w2_ms := _ms(func(): JsonStable.write_file(path, s2.to_dict()))
		var bytes2 := FileAccess.get_file_as_bytes(path)
		print("[PERF] sch 1k write1 %d ms; write2 %d ms" % [w1_ms, w2_ms])
		if bytes1 != bytes2:
			return "round-trip not byte-stable: %d vs %d" % [bytes1.size(), bytes2.size()]
		if w2_ms > 1000:
			return "second write too slow: %d ms" % w2_ms
		return ""))
	return r
