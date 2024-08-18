@tool
class_name MidiFormatLoader 
extends ResourceFormatLoader


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["mid"])


func _get_resource_type(path: String):
	var ext = path.get_extension().to_lower()
	if ext == "mid":
		return "Resource"
	return ""


func _handles_type(type: StringName) -> bool:
	return ClassDB.is_parent_class(type, "Resource")


func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int):
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		var error = FileAccess.get_open_error()
		MidiData._log("File not opened: %d" % error)
		return error
	var midi_data := MidiData.load_packed_byte_array(bytes)
	if midi_data == null:
		return ERR_PARSE_ERROR
	return midi_data
