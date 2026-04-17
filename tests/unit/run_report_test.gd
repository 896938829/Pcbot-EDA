class_name RunReportTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("write last-run.json", func():
		var root := "user://runreport_test"
		DirAccess.make_dir_recursive_absolute(root)
		var res := Result.success({"hello": 1})
		res.add_touched(root + "/foo.sch.json")
		RunReport.write(root, "test.cmd", {"x": 1}, res)
		var p := ProjectFs.pcbot_dir(root).path_join("last-run.json")
		if not FileAccess.file_exists(p):
			return "last-run.json not written"
		var d = JsonStable.read_file(p)
		if str(d.get("command", "")) != "test.cmd":
			return "command wrong"
		if int(d.get("exit_code", -1)) != 0:
			return "exit_code wrong"
		return ""))
	r.append(Assert.case("err exit_code propagates", func():
		var root := "user://runreport_test2"
		DirAccess.make_dir_recursive_absolute(root)
		RunReport.write(root, "bad.cmd", {}, Result.err(3, "rule violation"))
		var d = JsonStable.read_file(ProjectFs.pcbot_dir(root).path_join("last-run.json"))
		return Assert.eq(int(d.get("exit_code", -1)), 3)))
	return r
