class_name JsonlTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("append and read", func():
		var p := "user://jsonl_test.jsonl"
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		Jsonl.append(p, {"a": 1})
		Jsonl.append(p, {"a": 2})
		var all := Jsonl.read_all(p)
		if all.size() != 2:
			return "expected 2 records, got %d" % all.size()
		if all[0].get("a", 0) != 1:
			return "first record wrong"
		return ""))
	return r
