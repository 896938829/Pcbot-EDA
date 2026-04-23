class_name GenLib
extends RefCounted

## 生成可复现的合成元件库 fixture（symbols + components JSON）。
## 用于 perf 测试与端到端基准。RNG 固定种子保证两次运行字节一致。

const SEED: int = 42


static func gen(root: String, n_symbols: int, n_components: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	DirAccess.make_dir_recursive_absolute(root + "/symbols")
	DirAccess.make_dir_recursive_absolute(root + "/components")

	var sym_ids: Array = []
	for i in n_symbols:
		var sid := "SYM%05d" % i
		sym_ids.append(sid)
		var pin_count: int = 2 + (i % 8)
		var pins: Array = []
		for k in pin_count:
			pins.append({
				"number": str(k + 1),
				"name": "P%d" % (k + 1),
				"pos": [k * 2_540_000, 0],
				"dir": "left" if k % 2 == 0 else "right",
			})
		JsonStable.write_file(root + "/symbols/" + sid + ".sym.json", {
			"format_version": 1,
			"id": sid,
			"name": sid,
			"pins": pins,
			"graphic_svg_ref": "",
			"bbox_nm": [0, 0, 10_000_000, 10_000_000],
			"metadata": {},
		})

	var manufacturers := ["Vishay", "TI", "STM", "ON", "NXP", "Maxim"]
	for i in n_components:
		var cid := "COMP%06d" % i
		var sym_ref: String = sym_ids[i % sym_ids.size()] if sym_ids.size() > 0 else ""
		JsonStable.write_file(root + "/components/" + cid + ".comp.json", {
			"format_version": 1,
			"id": cid,
			"part_number": "PN-%06d-%d" % [i, rng.randi_range(0, 9999)],
			"manufacturer": manufacturers[i % manufacturers.size()],
			"description": "Synthetic component #%d" % i,
			"symbol_ref": "symbols/" + sym_ref + ".sym.json" if sym_ref != "" else "",
			"footprint_refs": [],
			"parameters": {},
		})
