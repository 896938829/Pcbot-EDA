class_name ResultTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("success ok=true", func():
		var s := Result.success({"x": 1})
		return Assert.truthy(s.ok)))
	r.append(Assert.case("err code preserved", func():
		var e := Result.err(1, "bad")
		if e.ok:
			return "should not be ok"
		if e.code != 1:
			return "code wrong"
		if e.errors.size() != 1:
			return "errors missing"
		return ""))
	r.append(Assert.case("rule_violation code=3", func():
		var v := Result.rule_violation("net.floating", "N1", "空网络")
		return Assert.eq(v.code, 3)))
	return r
