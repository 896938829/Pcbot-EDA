class_name Assert
extends RefCounted

## 极简断言工具。返回 [name, ok, msg] 的构造辅助。


static func case(name: String, cb: Callable) -> Dictionary:
	var ok := false
	var msg := ""
	var err = cb.call()
	if typeof(err) == TYPE_STRING and err != "":
		msg = err
	else:
		ok = true
	return {"name": name, "ok": ok, "msg": msg}


static func eq(a, b, note := "") -> String:
	if a == b:
		return ""
	return "expected %s == %s%s" % [str(a), str(b), (" (%s)" % note) if note != "" else ""]


static func neq(a, b) -> String:
	if a != b:
		return ""
	return "expected %s != %s" % [str(a), str(b)]


static func truthy(v, note := "") -> String:
	if v:
		return ""
	return "expected truthy%s" % ((" (%s)" % note) if note != "" else "")


static func contains(container, item) -> String:
	if container.has(item):
		return ""
	return "expected container to contain %s" % str(item)
