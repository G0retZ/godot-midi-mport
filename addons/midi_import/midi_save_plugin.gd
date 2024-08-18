@tool
class_name MidiFormatSaver
extends ResourceFormatSaver


func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	return PackedStringArray(["mid"])


func _recognize(resource: Resource) -> bool:
	return resource is MidiData


func _save(resource: Resource, path: String, flags: int) -> Error:
	var data = resource as MidiData
	if data == null:
		return ERR_INVALID_DATA
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(data._bytes)
	file.close()
	return OK
