class_name GuiEditRoundtripTest
extends RefCounted

## M1.2 P16：GUI 编辑路径的 CLI 层级 integration 覆盖。
## 模拟"拖元件 → 属性改名 → 旋转 → 移位 → 删除"流，逐步落盘验证。


static func _reg() -> CommandRegistry:
	var r := CommandRegistry.new()
	SchematicCommands.register(r)
	return r


static func run() -> Array:
	var r: Array = []
	var abs := ProjectSettings.globalize_path("user://p16_gui_edit_roundtrip.sch.json")
	var reg := _reg()

	r.append(Assert.case("new + place + annotate + set_property + rotate + move + delete", func():
		## 清 file
		if FileAccess.file_exists(abs):
			DirAccess.remove_absolute(abs)
		var n: Result = reg.call_method("schematic.new", {"path": abs, "id": "roundtrip"})
		if not n.ok:
			return "new failed: %s" % n.message

		## 放 3 个 placement，reference 以 ? 结尾；annotate 填号
		for i in 3:
			var rr: Result = reg.call_method("schematic.place_component", {
				"path": abs, "component_ref": "R", "reference": "R?", "pos_nm": [i * 1_000_000, 0],
			})
			if not rr.ok:
				return "place %d failed: %s" % [i, rr.message]
			reg.call_method("schematic.annotate", {"path": abs})

		var data = JsonStable.read_file(abs)
		var s := Schematic.from_dict(data)
		if s.placements.size() != 3:
			return "expect 3 placements, got %d" % s.placements.size()
		## 三个 reference 应该是 R1/R2/R3
		var refs: Array = []
		for pl in s.placements:
			refs.append(str(pl.get("reference", "")))
		refs.sort()
		if str(refs) != "[\"R1\", \"R2\", \"R3\"]":
			return "refs=%s" % str(refs)

		## set_property rename R1 → R99
		var p1_uid := str(s.find_placement_by_ref("R1").get("uid", ""))
		var sp: Result = reg.call_method("schematic.set_property", {
			"path": abs, "placement_uid": p1_uid, "key": "reference", "value": "R99",
		})
		if not sp.ok:
			return "set_property failed: %s" % sp.message

		## rotate_placement 90
		var rp: Result = reg.call_method("schematic.rotate_placement", {
			"path": abs, "placement_uid": p1_uid, "rotation_deg": 90,
		})
		if not rp.ok:
			return "rotate failed: %s" % rp.message

		## move_placement
		var mv: Result = reg.call_method("schematic.move_placement", {
			"path": abs, "placement_uid": p1_uid, "pos_nm": [10_000_000, 20_000_000],
		})
		if not mv.ok:
			return "move failed: %s" % mv.message

		## 验证综合效果
		var s2 := Schematic.from_dict(JsonStable.read_file(abs))
		var pl: Dictionary = s2.find_placement(p1_uid)
		if str(pl.get("reference", "")) != "R99":
			return "reference 未更新"
		if int(pl.get("rotation_deg", 0)) != 90:
			return "rotation 未更新"
		if int(pl.get("pos_nm", [0, 0])[0]) != 10_000_000:
			return "pos_nm 未更新"

		## remove_placement R2
		var p2_uid := str(s2.find_placement_by_ref("R2").get("uid", ""))
		var rm: Result = reg.call_method("schematic.remove_placement", {
			"path": abs, "placement_uid": p2_uid,
		})
		if not rm.ok:
			return "remove failed: %s" % rm.message

		var s3 := Schematic.from_dict(JsonStable.read_file(abs))
		return Assert.eq(s3.placements.size(), 2)))

	r.append(Assert.case("remove_placement → inverse 重建 roundtrip", func():
		var p := ProjectSettings.globalize_path("user://p7_remove_undo_roundtrip.sch.json")
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		var rg := _reg()
		var n0: Result = rg.call_method("schematic.new", {"path": p, "id": "ru"})
		if not n0.ok:
			return "new: %s" % n0.message
		## 两个元件 + 一条连线，确保 remove 会触发 net 快照
		var pa: Result = rg.call_method("schematic.place_component", {
			"path": p, "component_ref": "R", "reference": "R1", "pos_nm": [0, 0],
		})
		if not pa.ok:
			return "place R1: %s" % pa.message
		var pb: Result = rg.call_method("schematic.place_component", {
			"path": p, "component_ref": "R", "reference": "R2", "pos_nm": [5_000_000, 0],
		})
		if not pb.ok:
			return "place R2: %s" % pb.message
		var cn: Result = rg.call_method("schematic.connect", {
			"path": p, "net": "NET_X", "pins": ["R1.1", "R2.1"],
		})
		if not cn.ok:
			return "connect: %s" % cn.message
		var before = JsonStable.read_file(p)
		var r1_uid := str(Schematic.from_dict(before).find_placement_by_ref("R1").get("uid", ""))

		## forward: remove R1
		var rm: Result = rg.call_method("schematic.remove_placement", {
			"path": p, "placement_uid": r1_uid,
		})
		if not rm.ok:
			return "remove: %s" % rm.message
		var snap: Dictionary = rm.data.get("placement_snapshot", {})
		if snap.is_empty():
			return "placement_snapshot missing"
		var nets: Array = rm.data.get("net_snapshots", [])
		if nets.is_empty():
			return "net_snapshots missing"

		## inverse: place_component + connect 每个 net 快照
		var ipa: Result = rg.call_method("schematic.place_component", {
			"path": p,
			"page_id": snap.get("page_id", "p1"),
			"component_ref": snap.get("component_ref", ""),
			"reference": snap.get("reference", ""),
			"pos_nm": snap.get("pos_nm", [0, 0]),
			"rotation_deg": snap.get("rotation_deg", 0),
			"mirror": snap.get("mirror", false),
		})
		if not ipa.ok:
			return "inverse place: %s" % ipa.message
		for net_snap in nets:
			var icn: Result = rg.call_method("schematic.connect", {
				"path": p,
				"net": net_snap.get("name", ""),
				"pins": net_snap.get("pins", []),
			})
			if not icn.ok:
				return "inverse connect: %s" % icn.message

		## 状态一致（placements + nets.pins 相等；uid 允许不同）
		var after := Schematic.from_dict(JsonStable.read_file(p))
		if after.placements.size() != 2:
			return "placements size=%d expect 2" % after.placements.size()
		if after.find_placement_by_ref("R1").is_empty():
			return "R1 not restored"
		if after.find_placement_by_ref("R2").is_empty():
			return "R2 not restored"
		var net_x: Dictionary = after.find_net_by_name("NET_X")
		if net_x.is_empty():
			return "NET_X not restored"
		var pins_after: Array = net_x.get("pins", [])
		if not (pins_after.has("R1.1") and pins_after.has("R2.1")):
			return "pins not restored: %s" % pins_after
		return ""))

	return r
