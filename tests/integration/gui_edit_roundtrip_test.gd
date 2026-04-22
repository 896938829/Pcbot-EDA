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

	return r
