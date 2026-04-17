class_name LedBlinkE2ETest
extends RefCounted

## LED 闪烁电路 e2e smoke：project.new → library.add_* → schematic.new → place → connect → check.basic。
## 故意留悬空网络 → check.basic 记录违例 → 补上连接 → 再 check.basic 记录 resolved。


static func _registry() -> CommandRegistry:
	var reg := CommandRegistry.new()
	ProjectCommands.register(reg)
	SymbolCommands.register(reg)
	LibraryCommands.register(reg)
	SchematicCommands.register(reg)
	CheckCommands.register(reg)
	return reg


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("e2e led blink", _do_e2e))
	return r


static func _do_e2e() -> String:
	var reg := _registry()
	var root := ProjectSettings.globalize_path("user://e2e_led")
	_wipe(root)
	DirAccess.make_dir_recursive_absolute(root)
	var project_path := root.path_join("led_blink.pcbproj")
	var sch_path := root.path_join("led_blink.sch.json")
	var lib_root := root.path_join("library")

	var pn: Result = reg.call_method("project.new", {"path": project_path, "name": "LED Blink"})
	if not pn.ok: return "project.new: %s" % pn.message

	for sym in _led_symbols():
		var res: Result = reg.call_method("library.add_symbol", {
			"lib_root": lib_root,
			"id": sym["id"],
			"name": sym["name"],
			"pins": sym["pins"],
		})
		if not res.ok: return "add_symbol %s: %s" % [sym["id"], res.message]

	for comp in _led_components():
		var res: Result = reg.call_method("library.add_component", {
			"lib_root": lib_root,
			"id": comp["id"],
			"manufacturer": comp.get("manufacturer", "Generic"),
			"part_number": comp.get("part_number", comp["id"]),
			"symbol_ref": comp["symbol_ref"],
			"parameters": comp.get("parameters", {}),
		})
		if not res.ok: return "add_component %s: %s" % [comp["id"], res.message]

	var sn: Result = reg.call_method("schematic.new", {"path": sch_path, "id": "led_blink"})
	if not sn.ok: return "schematic.new: %s" % sn.message

	var placements := [
		{"ref": "U1", "comp": "NE555"},
		{"ref": "R1", "comp": "R-10k"},
		{"ref": "R2", "comp": "R-10k"},
		{"ref": "C1", "comp": "C-10uF"},
		{"ref": "D1", "comp": "LED"},
		{"ref": "R3", "comp": "R-330"},
		{"ref": "VCC1", "comp": "VCC"},
		{"ref": "GND1", "comp": "GND"},
	]
	var x := 0
	for p in placements:
		var res: Result = reg.call_method("schematic.place_component", {
			"path": sch_path,
			"component_ref": p["comp"],
			"reference": p["ref"],
			"pos_nm": [x, 0],
		})
		if not res.ok: return "place %s: %s" % [p["ref"], res.message]
		x += 30_000_000

	## 连接——故意省略 C1.1 到 U1.2/U1.6，留一个悬空（触发 net.floating 或 placement.unconnected）。
	var connects := [
		{"net": "VCC", "pins": ["VCC1.1", "U1.8", "U1.4", "R1.1"]},
		{"net": "GND", "pins": ["GND1.1", "U1.1", "C1.2"]},
		{"net": "N_OUT", "pins": ["U1.3", "R3.1"]},
		{"net": "N_LED", "pins": ["R3.2", "D1.1"]},
		{"net": "N_LED_K", "pins": ["D1.2", "GND1.1"]},
		{"net": "N_THR", "pins": ["R1.2", "R2.1"]},
		## 故意不连 U1.2 / U1.6 / C1.1 / R2.2 → 违例
	]
	for c in connects:
		var res: Result = reg.call_method("schematic.connect", {
			"path": sch_path,
			"net": c["net"],
			"pins": c["pins"],
		})
		if not res.ok: return "connect %s: %s" % [c["net"], res.message]

	var c1: Result = reg.call_method("check.basic", {"schematic": sch_path, "project_root": root})
	if c1.ok: return "check.basic should have failed on floating nets"
	if c1.code != 3: return "expected code=3 (RULE_VIOLATION), got %d" % c1.code
	var diag_path := DiagnosticsLog.path(root)
	if not FileAccess.file_exists(diag_path): return "diagnostics.jsonl not created"
	var before := Jsonl.read_all(diag_path).size()
	if before <= 0: return "diagnostics empty"

	## 补上缺失网络，消除违例
	var fixups := [
		{"net": "N_THR", "pins": ["R2.2", "C1.1", "U1.2", "U1.6"]},
	]
	for f in fixups:
		var res: Result = reg.call_method("schematic.connect", {
			"path": sch_path,
			"net": f["net"],
			"pins": f["pins"],
		})
		if not res.ok: return "fix connect %s: %s" % [f["net"], res.message]

	var c2: Result = reg.call_method("check.basic", {"schematic": sch_path, "project_root": root})
	var after_records := Jsonl.read_all(diag_path)
	if after_records.size() <= before: return "no new diagnostics lines after fix"
	var has_resolved := false
	for rec in after_records:
		if rec.get("resolved_by_commit", null) != null:
			has_resolved = true
			break
	if not has_resolved: return "expected at least one resolved_by_commit record"
	if not c2.ok:
		## 允许仍有 warning（未连入网络的放置类），但 error 不应存在
		if c2.code == 3:
			return "still rule violation after fix: %s" % c2.message

	## 更新 project 的 schematic_refs
	var pj_data = JsonStable.read_file(project_path)
	var pj := DesignProject.from_dict(pj_data)
	pj.schematic_refs = ["led_blink.sch.json"]
	pj.library_refs = ["library"]
	JsonStable.write_file(project_path, pj.to_dict())

	return ""


static func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	while true:
		var f := da.get_next()
		if f == "":
			break
		if f == "." or f == "..":
			continue
		var full := path.path_join(f)
		if da.current_is_dir():
			_wipe(full)
			DirAccess.remove_absolute(full)
		else:
			DirAccess.remove_absolute(full)
	da.list_dir_end()


static func _led_symbols() -> Array:
	var mm := UnitSystem.NM_PER_MM
	return [
		{"id": "NE555", "name": "NE555", "pins": [
			{"number": "1", "name": "GND",  "pos": [0, 0],     "dir": "left"},
			{"number": "2", "name": "TRIG", "pos": [0, mm * 2],"dir": "left"},
			{"number": "3", "name": "OUT",  "pos": [mm * 10, mm * 2],"dir": "right"},
			{"number": "4", "name": "RST",  "pos": [mm * 5, mm * 10],"dir": "up"},
			{"number": "5", "name": "CTRL", "pos": [mm * 10, mm * 6],"dir": "right"},
			{"number": "6", "name": "THR",  "pos": [0, mm * 4], "dir": "left"},
			{"number": "7", "name": "DIS",  "pos": [0, mm * 6], "dir": "left"},
			{"number": "8", "name": "VCC",  "pos": [mm * 5, 0], "dir": "down"},
		]},
		{"id": "R-10k",  "name": "R-10k",  "pins": _two_pins()},
		{"id": "R-330",  "name": "R-330",  "pins": _two_pins()},
		{"id": "C-10uF", "name": "C-10uF", "pins": _two_pins()},
		{"id": "LED",    "name": "LED",    "pins": [
			{"number": "1", "name": "A", "pos": [0, 0], "dir": "left"},
			{"number": "2", "name": "K", "pos": [UnitSystem.NM_PER_MM * 2, 0], "dir": "right"},
		]},
		{"id": "VCC",    "name": "VCC",    "pins": [{"number": "1", "name": "VCC", "pos": [0, 0], "dir": "up"}]},
		{"id": "GND",    "name": "GND",    "pins": [{"number": "1", "name": "GND", "pos": [0, 0], "dir": "down"}]},
	]


static func _two_pins() -> Array:
	var mm := UnitSystem.NM_PER_MM
	return [
		{"number": "1", "name": "1", "pos": [0, 0],       "dir": "left"},
		{"number": "2", "name": "2", "pos": [mm * 4, 0],  "dir": "right"},
	]


static func _led_components() -> Array:
	return [
		{"id": "NE555",  "symbol_ref": "symbols/NE555.sym.json",  "part_number": "NE555P",  "parameters": {}},
		{"id": "R-10k",  "symbol_ref": "symbols/R-10k.sym.json",  "part_number": "RC0603-10k"},
		{"id": "R-330",  "symbol_ref": "symbols/R-330.sym.json",  "part_number": "RC0603-330"},
		{"id": "C-10uF", "symbol_ref": "symbols/C-10uF.sym.json", "part_number": "CAP0603-10uF"},
		{"id": "LED",    "symbol_ref": "symbols/LED.sym.json",    "part_number": "LED-0603-RED"},
		{"id": "VCC",    "symbol_ref": "symbols/VCC.sym.json",    "part_number": "VCC-port"},
		{"id": "GND",    "symbol_ref": "symbols/GND.sym.json",    "part_number": "GND-port"},
	]
