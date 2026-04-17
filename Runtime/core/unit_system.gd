class_name UnitSystem
extends RefCounted

## 单位换算：内部统一用 int64 纳米（nm）。展示层才换算。

const NM_PER_MM: int = 1_000_000
const NM_PER_MIL: int = 25_400
const NM_PER_INCH: int = 25_400_000


static func mm_to_nm(mm: float) -> int:
	return int(round(mm * NM_PER_MM))


static func nm_to_mm(nm: int) -> float:
	return float(nm) / float(NM_PER_MM)


static func mil_to_nm(mil: float) -> int:
	return int(round(mil * NM_PER_MIL))


static func nm_to_mil(nm: int) -> float:
	return float(nm) / float(NM_PER_MIL)


static func vec_mm_to_nm(v: Vector2) -> Vector2i:
	return Vector2i(mm_to_nm(v.x), mm_to_nm(v.y))


static func vec_nm_to_mm(v: Vector2i) -> Vector2:
	return Vector2(nm_to_mm(v.x), nm_to_mm(v.y))
