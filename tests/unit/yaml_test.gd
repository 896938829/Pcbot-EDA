class_name YamlTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("parse flat keys", func():
		var y = YamlIO.parse("name: project.new\ndescription: hi\n")
		if typeof(y) != TYPE_DICTIONARY:
			return "expected dict"
		if str(y.get("name", "")) != "project.new":
			return "bad name: %s" % str(y.get("name", ""))
		return ""))
	r.append(Assert.case("parse nested", func():
		var text := "outer:\n  inner: 1\n  list:\n    - a\n    - b\n"
		var y = YamlIO.parse(text)
		var outer = y.get("outer", {})
		if int(outer.get("inner", 0)) != 1:
			return "inner wrong"
		var lst: Array = outer.get("list", [])
		if lst.size() != 2 or str(lst[0]) != "a":
			return "list wrong"
		return ""))
	r.append(Assert.case("parse skill-like YAML", func():
		var text := "name: foo\nparams:\n  path: p\ncommon_errors:\n  - code: USER_ERROR\n    when: empty\n"
		var y = YamlIO.parse(text)
		if str(y.get("name", "")) != "foo":
			return "name"
		var ce: Array = y.get("common_errors", [])
		if ce.size() != 1 or str(ce[0].get("code", "")) != "USER_ERROR":
			return "common_errors"
		return ""))
	return r
