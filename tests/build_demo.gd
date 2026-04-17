extends SceneTree

## 生成 demo/led_blink 工程全套文件（稳定 JSON 序列化）。
## 运行：godot --headless -s tests/build_demo.gd


func _init() -> void:
	var root := ProjectSettings.globalize_path("res://demo")
	var reg := CommandRegistry.new()
	ProjectCommands.register(reg)
	SymbolCommands.register(reg)
	LibraryCommands.register(reg)
	SchematicCommands.register(reg)
	CheckCommands.register(reg)

	DirAccess.make_dir_recursive_absolute(root)
	var project_path := root.path_join("led_blink.pcbproj")
	var sch_path := root.path_join("led_blink.sch.json")
	var lib_root := root.path_join("library")

	reg.call_method("project.new", {"path": project_path, "name": "LED Blink"})
	_add_symbols(reg, lib_root)
	_add_components(reg, lib_root)

	reg.call_method("schematic.new", {"path": sch_path, "id": "led_blink"})
	_place_all(reg, sch_path)
	_connect_all(reg, sch_path)

	## 把工程的 schematic/library refs 写回
	var data = JsonStable.read_file(project_path)
	var pj := DesignProject.from_dict(data)
	pj.schematic_refs = ["led_blink.sch.json"]
	pj.library_refs = ["library"]
	JsonStable.write_file(project_path, pj.to_dict())

	## 触发一次 check.basic 产出 .pcbot/diagnostics.jsonl（若无违例则为空文件）
	var c: Result = reg.call_method("check.basic", {"schematic": sch_path, "project_root": root})
	print("check.basic ok=%s code=%d warnings=%d" % [c.ok, c.code, c.warnings.size()])

	quit(0)


func _add_symbols(reg: CommandRegistry, lib_root: String) -> void:
	var mm := UnitSystem.NM_PER_MM
	var specs := [
		{"id": "NE555", "pins": [
			{"number": "1", "name": "GND",  "pos": [0, 0],      "dir": "left"},
			{"number": "2", "name": "TRIG", "pos": [0, mm * 2], "dir": "left"},
			{"number": "3", "name": "OUT",  "pos": [mm * 10, mm * 2], "dir": "right"},
			{"number": "4", "name": "RST",  "pos": [mm * 5, mm * 10], "dir": "up"},
			{"number": "5", "name": "CTRL", "pos": [mm * 10, mm * 6], "dir": "right"},
			{"number": "6", "name": "THR",  "pos": [0, mm * 4],  "dir": "left"},
			{"number": "7", "name": "DIS",  "pos": [0, mm * 6],  "dir": "left"},
			{"number": "8", "name": "VCC",  "pos": [mm * 5, 0],  "dir": "down"},
		]},
		{"id": "R-10k", "pins": _two_pins()},
		{"id": "R-330", "pins": _two_pins()},
		{"id": "C-10uF", "pins": _two_pins()},
		{"id": "LED", "pins": [
			{"number": "1", "name": "A", "pos": [0, 0], "dir": "left"},
			{"number": "2", "name": "K", "pos": [mm * 2, 0], "dir": "right"},
		]},
		{"id": "VCC", "pins": [{"number": "1", "name": "VCC", "pos": [0, 0], "dir": "up"}]},
		{"id": "GND", "pins": [{"number": "1", "name": "GND", "pos": [0, 0], "dir": "down"}]},
	]
	for s in specs:
		reg.call_method("library.add_symbol", {
			"lib_root": lib_root,
			"id": s["id"],
			"name": s["id"],
			"pins": s["pins"],
		})


func _add_components(reg: CommandRegistry, lib_root: String) -> void:
	var specs := [
		{"id": "NE555",  "part_number": "NE555P",       "symbol_ref": "symbols/NE555.sym.json"},
		{"id": "R-10k",  "part_number": "RC0603-10k",   "symbol_ref": "symbols/R-10k.sym.json"},
		{"id": "R-330",  "part_number": "RC0603-330",   "symbol_ref": "symbols/R-330.sym.json"},
		{"id": "C-10uF", "part_number": "CAP0603-10uF", "symbol_ref": "symbols/C-10uF.sym.json"},
		{"id": "LED",    "part_number": "LED-0603-RED", "symbol_ref": "symbols/LED.sym.json"},
		{"id": "VCC",    "part_number": "VCC-port",     "symbol_ref": "symbols/VCC.sym.json"},
		{"id": "GND",    "part_number": "GND-port",     "symbol_ref": "symbols/GND.sym.json"},
	]
	for c in specs:
		reg.call_method("library.add_component", {
			"lib_root": lib_root,
			"id": c["id"],
			"manufacturer": "Generic",
			"part_number": c["part_number"],
			"symbol_ref": c["symbol_ref"],
		})


func _place_all(reg: CommandRegistry, sch: String) -> void:
	var mm := UnitSystem.NM_PER_MM
	var placements := [
		{"ref": "U1", "comp": "NE555", "pos": [mm * 100, mm * 80]},
		{"ref": "R1", "comp": "R-10k", "pos": [mm * 140, mm * 40]},
		{"ref": "R2", "comp": "R-10k", "pos": [mm * 140, mm * 70]},
		{"ref": "C1", "comp": "C-10uF","pos": [mm * 80,  mm * 100]},
		{"ref": "R3", "comp": "R-330", "pos": [mm * 170, mm * 90]},
		{"ref": "D1", "comp": "LED",   "pos": [mm * 200, mm * 90]},
		{"ref": "VCC1","comp": "VCC",  "pos": [mm * 120, mm * 20]},
		{"ref": "GND1","comp": "GND",  "pos": [mm * 120, mm * 140]},
	]
	for p in placements:
		reg.call_method("schematic.place_component", {
			"path": sch,
			"component_ref": p["comp"],
			"reference": p["ref"],
			"pos_nm": p["pos"],
		})


func _connect_all(reg: CommandRegistry, sch: String) -> void:
	var nets := [
		{"net": "VCC",       "pins": ["VCC1.1", "U1.4", "U1.8", "R1.1"]},
		{"net": "GND",       "pins": ["GND1.1", "U1.1", "C1.2", "D1.2"]},
		{"net": "DISCHARGE", "pins": ["U1.7", "R1.2", "R2.1"]},
		{"net": "TIMING",    "pins": ["U1.2", "U1.6", "R2.2", "C1.1"]},
		{"net": "OUT",       "pins": ["U1.3", "R3.1"]},
		{"net": "LED_A",     "pins": ["R3.2", "D1.1"]},
	]
	for n in nets:
		reg.call_method("schematic.connect", {
			"path": sch,
			"net": n["net"],
			"pins": n["pins"],
		})


func _two_pins() -> Array:
	var mm := UnitSystem.NM_PER_MM
	return [
		{"number": "1", "name": "1", "pos": [0, 0],       "dir": "left"},
		{"number": "2", "name": "2", "pos": [mm * 4, 0],  "dir": "right"},
	]
