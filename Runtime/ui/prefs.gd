class_name Prefs
extends RefCounted

## 用户偏好持久化（M1.2 P15）。user://prefs.json。
## 承载：recent 工程（≤5）、dock 可见性、grid 密度、theme 标签。

const PATH := "user://prefs.json"
const RECENT_MAX := 5

var _data: Dictionary = {
	"recent": [],
	"dock_left": true,
	"dock_right": true,
	"dock_bottom": true,
	"grid_density_idx": 1,
	"theme": "dark",
}


func load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var d = JSON.parse_string(text)
	if typeof(d) == TYPE_DICTIONARY:
		for k in d.keys():
			_data[k] = d[k]


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()


func get_value(key: String, default_v):
	return _data.get(key, default_v)


func set_value(key: String, value) -> void:
	_data[key] = value
	save()


func recent() -> Array:
	return _data.get("recent", [])


func add_recent(path: String) -> void:
	var list: Array = _data.get("recent", []).duplicate()
	list.erase(path)
	list.push_front(path)
	while list.size() > RECENT_MAX:
		list.pop_back()
	_data["recent"] = list
	save()
