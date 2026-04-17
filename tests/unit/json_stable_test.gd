class_name JsonStableTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("dict keys sorted", func():
		var s := JsonStable.stringify({"b": 1, "a": 2})
		return Assert.truthy(s.find("\"a\"") < s.find("\"b\""), "a should precede b")))
	r.append(Assert.case("trailing newline", func():
		var s := JsonStable.stringify({"x": 1})
		return Assert.truthy(s.ends_with("\n"))))
	r.append(Assert.case("round-trip byte-stable", func():
		var original := {"nested": {"c": 3, "a": 1}, "arr": [2, 1, 3]}
		var s1 := JsonStable.stringify(original)
		var p: Variant = JsonStable.parse(s1)
		var s2 := JsonStable.stringify(p)
		return Assert.eq(s1, s2)))
	r.append(Assert.case("write and read file", func():
		var tmp := "user://json_stable_test.json"
		JsonStable.write_file(tmp, {"k": "v"})
		var d = JsonStable.read_file(tmp)
		return Assert.eq(d.get("k", ""), "v")))
	return r
