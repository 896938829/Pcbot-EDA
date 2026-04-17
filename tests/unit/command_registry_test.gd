class_name CommandRegistryTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("register + call", func():
		var reg := CommandRegistry.new()
		reg.add("t.ok", func(p): return Result.success({"echo": p.get("x", 0)}))
		var res: Result = reg.call_method("t.ok", {"x": 42})
		if not res.ok:
			return "expected ok"
		return Assert.eq(int(res.data.get("echo", 0)), 42)))
	r.append(Assert.case("unknown method -> err", func():
		var reg := CommandRegistry.new()
		var res := reg.call_method("none", {})
		return Assert.truthy(not res.ok)))
	return r
