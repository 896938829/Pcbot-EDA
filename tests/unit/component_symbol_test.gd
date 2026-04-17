class_name ComponentSymbolTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("round-trip dict", func():
		var s := ComponentSymbol.new()
		s.id = "LED"
		s.name = "LED"
		s.pins = [{"number": "2", "name": "K", "pos": [0, 0], "dir": "right"}, {"number": "1", "name": "A", "pos": [0, 0], "dir": "left"}]
		var d := s.to_dict()
		var pins: Array = d.get("pins", [])
		if pins.size() != 2 or str(pins[0].get("number", "")) != "1":
			return "pins not sorted by number"
		var s2 := ComponentSymbol.from_dict(d)
		return Assert.eq(s2.id, "LED")))
	r.append(Assert.case("find_pin", func():
		var s := ComponentSymbol.new()
		s.pins = [{"number": "1", "name": "A"}]
		var p := s.find_pin("1")
		return Assert.eq(p.get("name", ""), "A")))
	return r
