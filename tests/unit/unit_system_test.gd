class_name UnitSystemTest
extends RefCounted


static func run() -> Array:
	var r: Array = []
	r.append(Assert.case("mm_to_nm precision", func():
		return Assert.eq(UnitSystem.mm_to_nm(1.0), 1_000_000)))
	r.append(Assert.case("nm_to_mm round-trip", func():
		return Assert.eq(UnitSystem.nm_to_mm(UnitSystem.mm_to_nm(12.5)), 12.5)))
	r.append(Assert.case("mil_to_nm", func():
		return Assert.eq(UnitSystem.mil_to_nm(1.0), 25_400)))
	r.append(Assert.case("vec mm->nm", func():
		var v := UnitSystem.vec_mm_to_nm(Vector2(2.0, -3.0))
		return Assert.eq(v, Vector2i(2_000_000, -3_000_000))))
	return r
