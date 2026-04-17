class_name LibraryIndexTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("scan + search", func():
		var root := "user://libidx_test"
		DirAccess.make_dir_recursive_absolute(root + "/symbols")
		DirAccess.make_dir_recursive_absolute(root + "/components")
		JsonStable.write_file(root + "/symbols/LED.sym.json", {"id": "LED", "name": "LED", "pins": []})
		JsonStable.write_file(root + "/components/LED-red.comp.json", {
			"id": "LED-red",
			"part_number": "LED-0603-RED",
			"manufacturer": "Generic",
			"symbol_ref": "symbols/LED.sym.json",
		})
		var idx := LibraryIndex.new()
		var n := idx.load_from_root(root)
		if n < 2:
			return "scan count %d" % n
		if idx.list_components().size() != 1:
			return "component count"
		if idx.search("RED").size() != 1:
			return "search failed"
		return ""))
	return r
