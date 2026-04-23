class_name SchematicCommands
extends RefCounted

## schematic.new / add_page / place_component / connect / annotate


const SET_PROPERTY_WHITELIST: Array = ["reference", "mirror"]


static func register(registry: CommandRegistry) -> void:
	registry.add("schematic.new", func(p): return _new(p))
	registry.add("schematic.add_page", func(p): return _add_page(p))
	registry.add("schematic.place_component", func(p): return _place_component(p))
	registry.add("schematic.connect", func(p): return _connect(p))
	registry.add("schematic.annotate", func(p): return _annotate(p))
	registry.add("schematic.set_property", func(p): return _set_property(p))
	registry.add("schematic.rotate_placement", func(p): return _rotate_placement(p))
	registry.add("schematic.move_placement", func(p): return _move_placement(p))
	registry.add("schematic.remove_placement", func(p): return _remove_placement(p))
	registry.add("schematic.remove_net", func(p): return _remove_net(p))
	registry.add("schematic.disconnect_pin", func(p): return _disconnect_pin(p))


static func _load(path: String) -> Schematic:
	var data = JsonStable.read_file(path)
	if data == null:
		return null
	return Schematic.from_dict(data)


static func _save(path: String, s: Schematic) -> int:
	return JsonStable.write_file(path, s.to_dict())


static func _new(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	if path == "":
		return Result.err(1, "missing 'path'")
	var s := Schematic.new()
	s.id = str(params.get("id", path.get_file().get_basename()))
	s.pages = [{
		"id": "p1",
		"name": "Main",
		"size_nm": [UnitSystem.mm_to_nm(297.0), UnitSystem.mm_to_nm(210.0)],
	}]
	var we := _save(path, s)
	if we != OK:
		return Result.err(2, "write failed: %d" % we)
	var r := Result.success({"path": path, "id": s.id})
	r.add_touched(path)
	return r


static func _add_page(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var page_id: String = str(params.get("page_id", ""))
	if path == "" or page_id == "":
		return Result.err(1, "missing 'path' or 'page_id'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	if not s.find_page(page_id).is_empty():
		return Result.err(1, "page already exists: %s" % page_id)
	s.pages.append({
		"id": page_id,
		"name": str(params.get("name", page_id)),
		"size_nm": params.get("size_nm", [UnitSystem.mm_to_nm(297.0), UnitSystem.mm_to_nm(210.0)]),
	})
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "page_id": page_id})
	r.add_touched(path)
	return r


static func _place_component(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var page_id: String = str(params.get("page_id", "p1"))
	var component_ref: String = str(params.get("component_ref", ""))
	var reference: String = str(params.get("reference", ""))
	var pos_nm: Array = params.get("pos_nm", [0, 0])
	if path == "" or component_ref == "" or reference == "":
		return Result.err(1, "missing 'path', 'component_ref' or 'reference'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	if s.find_page(page_id).is_empty():
		return Result.err(1, "page not found: %s" % page_id)
	if not s.find_placement_by_ref(reference).is_empty():
		return Result.err(1, "reference already used: %s" % reference)
	var pl := SchPlacement.new()
	pl.uid = s.next_placement_uid()
	pl.page_id = page_id
	pl.component_ref = component_ref
	pl.reference = reference
	pl.pos_nm = pos_nm
	pl.rotation_deg = int(params.get("rotation_deg", 0))
	pl.mirror = bool(params.get("mirror", false))
	s.placements.append(pl.to_dict())
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "uid": pl.uid, "reference": reference})
	r.add_touched(path)
	return r


static func _connect(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var net_name: String = str(params.get("net", ""))
	var pins: Array = params.get("pins", [])
	if path == "" or pins.is_empty():
		return Result.err(1, "missing 'path' or 'pins'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	for pin_ref in pins:
		var parts := str(pin_ref).split(".")
		if parts.size() != 2:
			return Result.err(1, "invalid pin ref: %s (expect 'REF.pin')" % pin_ref)
		if s.find_placement_by_ref(parts[0]).is_empty():
			return Result.err(1, "unknown placement: %s" % parts[0])

	var net_dict: Dictionary = {}
	if net_name != "":
		net_dict = s.find_net_by_name(net_name)
	var is_new := net_dict.is_empty()
	var result_net_id := ""
	var result_net_name := net_name
	var added_pins: Array = []
	if is_new:
		var n := SchNet.new()
		n.id = s.next_net_id()
		n.name = net_name if net_name != "" else n.id
		n.pins = []
		for p in pins:
			var ps := str(p)
			if not n.pins.has(ps):
				n.pins.append(ps)
				added_pins.append(ps)
		result_net_id = n.id
		result_net_name = n.name
		s.nets.append(n.to_dict())
	else:
		var existing_pins: Array = net_dict.get("pins", [])
		for p in pins:
			var ps2 := str(p)
			if not existing_pins.has(ps2):
				existing_pins.append(ps2)
				added_pins.append(ps2)
		net_dict["pins"] = existing_pins
		result_net_id = str(net_dict.get("id", ""))
		result_net_name = str(net_dict.get("name", net_name))

	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({
		"path": path,
		"net": result_net_name,
		"net_id": result_net_id,
		"is_new": is_new,
		"added_pins": added_pins,
		"pin_count": pins.size(),
	})
	r.add_touched(path)
	return r


static func _set_property(params: Dictionary) -> Result:
	## 修改单个 placement 的可白名单字段。
	## key ∈ SET_PROPERTY_WHITELIST（reference / mirror）。
	## rotation_deg 走 schematic.rotate_placement（独立原子），pos_nm 走 move_placement。
	var path: String = str(params.get("path", ""))
	var uid: String = str(params.get("placement_uid", ""))
	var key: String = str(params.get("key", ""))
	if path == "" or uid == "" or key == "":
		return Result.err(1, "missing 'path', 'placement_uid' or 'key'")
	if not SET_PROPERTY_WHITELIST.has(key):
		return Result.err(1, "key not in whitelist: %s (allowed: %s)" % [key, SET_PROPERTY_WHITELIST])
	var value = params.get("value", null)
	if value == null:
		return Result.err(1, "missing 'value'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	var pl: Dictionary = s.find_placement(uid)
	if pl.is_empty():
		return Result.err(1, "placement not found: %s" % uid)
	if key == "reference":
		var new_ref: String = str(value)
		if new_ref == "":
			return Result.err(1, "reference cannot be empty")
		var other: Dictionary = s.find_placement_by_ref(new_ref)
		if not other.is_empty() and str(other.get("uid", "")) != uid:
			return Result.err(1, "reference already used: %s" % new_ref)
		pl["reference"] = new_ref
	elif key == "mirror":
		pl["mirror"] = bool(value)
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "uid": uid, "key": key, "value": pl[key]})
	r.add_touched(path)
	return r


static func _rotate_placement(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var uid: String = str(params.get("placement_uid", ""))
	if path == "" or uid == "":
		return Result.err(1, "missing 'path' or 'placement_uid'")
	if not params.has("rotation_deg"):
		return Result.err(1, "missing 'rotation_deg'")
	var rot := int(params["rotation_deg"]) % 360
	if rot < 0:
		rot += 360
	if rot % 90 != 0:
		return Result.err(1, "rotation_deg must be multiple of 90, got %d" % rot)
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	var pl: Dictionary = s.find_placement(uid)
	if pl.is_empty():
		return Result.err(1, "placement not found: %s" % uid)
	pl["rotation_deg"] = rot
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "uid": uid, "rotation_deg": rot})
	r.add_touched(path)
	return r


static func _move_placement(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var uid: String = str(params.get("placement_uid", ""))
	if path == "" or uid == "":
		return Result.err(1, "missing 'path' or 'placement_uid'")
	if not params.has("pos_nm"):
		return Result.err(1, "missing 'pos_nm'")
	var pos: Array = params["pos_nm"]
	if pos.size() != 2:
		return Result.err(1, "pos_nm must be [x, y]")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	var pl: Dictionary = s.find_placement(uid)
	if pl.is_empty():
		return Result.err(1, "placement not found: %s" % uid)
	pl["pos_nm"] = [int(pos[0]), int(pos[1])]
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "uid": uid, "pos_nm": pl["pos_nm"]})
	r.add_touched(path)
	return r


static func _remove_placement(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var uid: String = str(params.get("placement_uid", ""))
	if path == "" or uid == "":
		return Result.err(1, "missing 'path' or 'placement_uid'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	var pl: Dictionary = s.find_placement(uid)
	if pl.is_empty():
		return Result.err(1, "placement not found: %s" % uid)
	var ref: String = str(pl.get("reference", ""))
	## 删除前快照 placement 与受影响 nets，供 undo 重建。
	var placement_snapshot: Dictionary = {
		"page_id": str(pl.get("page_id", "p1")),
		"component_ref": str(pl.get("component_ref", "")),
		"reference": ref,
		"pos_nm": (pl.get("pos_nm", [0, 0]) as Array).duplicate(),
		"rotation_deg": int(pl.get("rotation_deg", 0)),
		"mirror": bool(pl.get("mirror", false)),
	}
	var net_snapshots: Array = []
	## 从 nets 中删除所有 ref.pin 引用；删除后若 net pins<2 则删 net
	var remaining_nets: Array = []
	var removed_nets: Array = []
	for n in s.nets:
		var pins: Array = n.get("pins", [])
		var touched := false
		for pin_ref in pins:
			var parts := str(pin_ref).split(".")
			if parts.size() == 2 and parts[0] == ref:
				touched = true
				break
		if touched:
			net_snapshots.append({
				"id": str(n.get("id", "")),
				"name": str(n.get("name", n.get("id", ""))),
				"pins": (pins as Array).duplicate(),
			})
		var kept: Array = []
		for pin_ref in pins:
			var parts2 := str(pin_ref).split(".")
			if parts2.size() == 2 and parts2[0] == ref:
				continue
			kept.append(pin_ref)
		if kept.size() >= 2:
			n["pins"] = kept
			remaining_nets.append(n)
		else:
			removed_nets.append(str(n.get("id", "")))
	s.nets = remaining_nets
	var kept_placements: Array = []
	for p in s.placements:
		if str(p.get("uid", "")) != uid:
			kept_placements.append(p)
	s.placements = kept_placements
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({
		"path": path,
		"uid": uid,
		"removed_nets": removed_nets,
		"placement_snapshot": placement_snapshot,
		"net_snapshots": net_snapshots,
	})
	r.add_touched(path)
	return r


static func _remove_net(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var net_id: String = str(params.get("net_id", ""))
	if path == "" or net_id == "":
		return Result.err(1, "missing 'path' or 'net_id'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	if s.find_net(net_id).is_empty():
		return Result.err(1, "net not found: %s" % net_id)
	var kept: Array = []
	for n in s.nets:
		if str(n.get("id", "")) != net_id:
			kept.append(n)
	s.nets = kept
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "net_id": net_id})
	r.add_touched(path)
	return r


static func _disconnect_pin(params: Dictionary) -> Result:
	var path: String = str(params.get("path", ""))
	var pin_ref: String = str(params.get("pin", ""))
	if path == "" or pin_ref == "":
		return Result.err(1, "missing 'path' or 'pin'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	var affected: Array = []
	var affected_names: Array = []
	var kept_nets: Array = []
	for n in s.nets:
		var pins: Array = n.get("pins", [])
		if pins.has(pin_ref):
			var remaining: Array = []
			for p in pins:
				if str(p) != pin_ref:
					remaining.append(p)
			if remaining.size() >= 2:
				n["pins"] = remaining
				kept_nets.append(n)
			affected.append(str(n.get("id", "")))
			affected_names.append(str(n.get("name", n.get("id", ""))))
		else:
			kept_nets.append(n)
	s.nets = kept_nets
	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({
		"path": path,
		"pin": pin_ref,
		"affected_nets": affected,
		"affected_net_names": affected_names,
	})
	r.add_touched(path)
	return r


static func _annotate(params: Dictionary) -> Result:
	## 自动重新编号未命名元件（reference 形如 "R?"）。按前缀独立分桶分配。
	## 参数：
	##   path: schematic 文件路径
	##   start_at: Dictionary，按前缀指定起始候选号，例如 {"R": 100, "U": 200}；
	##             从该号起按递增顺序跳过已被占用的号，落到第一个空位。
	##             默认 1。当无 start_at 时，"填 gap" 语义生效（如 R1/R3 已占，
	##             两个 R? 分别得 R2/R4）。
	var path: String = str(params.get("path", ""))
	if path == "":
		return Result.err(1, "missing 'path'")
	var s := _load(path)
	if s == null:
		return Result.err(1, "schematic not found")
	var start_at: Dictionary = params.get("start_at", {}) if params.get("start_at") is Dictionary else {}

	## 收集每个前缀已被占用的号段 → used[prefix] = {num: true}
	var used: Dictionary = {}
	for pl in s.placements:
		var ref: String = str(pl.get("reference", ""))
		if ref.ends_with("?") or ref == "":
			continue
		var prefix := ""
		var num := -1
		for i in ref.length():
			if ref[i].is_valid_int():
				prefix = ref.substr(0, i)
				num = int(ref.substr(i))
				break
		if prefix == "" or num < 0:
			continue
		if not used.has(prefix):
			used[prefix] = {}
		(used[prefix] as Dictionary)[num] = true

	## 每个前缀的候选起号；默认从 1（或 start_at[prefix]）开始，遇到占用号逐个跳。
	## 不跳到已用最大号之后——保持"填 gap"语义，避免空号段浪费。
	var next_num: Dictionary = {}
	for prefix in used.keys():
		next_num[prefix] = max(int(start_at.get(prefix, 1)), 1)
	for prefix in start_at.keys():
		if not next_num.has(prefix):
			next_num[prefix] = max(int(start_at[prefix]), 1)
		if not used.has(prefix):
			used[prefix] = {}

	var renamed := 0
	for pl in s.placements:
		var ref: String = str(pl.get("reference", ""))
		if not ref.ends_with("?"):
			continue
		var prefix := ref.substr(0, ref.length() - 1)
		if not used.has(prefix):
			used[prefix] = {}
		if not next_num.has(prefix):
			next_num[prefix] = int(start_at.get(prefix, 1))
		var n: int = int(next_num[prefix])
		while (used[prefix] as Dictionary).has(n):
			n += 1
		(used[prefix] as Dictionary)[n] = true
		next_num[prefix] = n + 1
		pl["reference"] = "%s%d" % [prefix, n]
		renamed += 1

	if _save(path, s) != OK:
		return Result.err(2, "write failed")
	var r := Result.success({"path": path, "renamed": renamed})
	r.add_touched(path)
	return r
