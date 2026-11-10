class_name Story
## Reads data/story.json (the intro panels and the victory lines).

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
		_data = d if typeof(d) == TYPE_DICTIONARY else {}
	return _data


static func panels(kind: String) -> Array:
	return data().get("multi" if kind != "single" else "single", [])


static func victory_lines(multi: bool) -> Array:
	return data().get("victory_multi" if multi else "victory_single", ["The solar system is safe."])
