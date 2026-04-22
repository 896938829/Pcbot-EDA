class_name CheckBasicPerfTest
extends RefCounted

## P5：check.basic 在 1k 元件下耗时基线。架构 §10：< 50 ms。


static func _ms(fn: Callable) -> int:
	var t0 := Time.get_ticks_msec()
	fn.call()
	return Time.get_ticks_msec() - t0


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("check_basic_1k_baseline", func():
		var path := "user://perf_check_1k.sch.json"
		var s := Schematic.new()
		s.id = "perf_check"
		s.pages = [{"id": "p1", "name": "Main", "size_nm": [297_000_000, 210_000_000]}]
		for i in 1000:
			s.placements.append({
				"uid": "pl%d" % (i + 1),
				"page_id": "p1",
				"component_id": "X",
				"reference": "R%d" % (i + 1),
				"pos_nm": [0, 0],
			})
		for i in 500:
			s.nets.append({
				"id": "N%d" % (i + 1),
				"name": "n%d" % i,
				"pins": ["R%d.1" % (i * 2 + 1), "R%d.2" % (i * 2 + 2)],
			})
		JsonStable.write_file(path, s.to_dict())
		var ms := _ms(func(): CheckCommands._basic({"schematic": path, "project_root": "user://perf_check_proj"}))
		print("[PERF] check.basic 1k pl/500 nets %d ms" % ms)
		if ms > 5000:
			return "check.basic too slow: %d ms" % ms
		return ""))
	return r
