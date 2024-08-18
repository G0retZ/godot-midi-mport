@tool
class_name MidiImportPlugin
extends EditorImportPlugin


func _get_importer_name():
	return "g0retz.midi"


func _get_visible_name():
	return "MIDI data"


func _get_recognized_extensions():
	return ["mid"]


func _get_save_extension():
	return "mid"


func _get_resource_type():
	return "Resource"


func _get_preset_count():
	return 0


func _get_preset_name(preset_index):
	return "Default"


func _get_priority():
	return 1.0


func _get_import_order():
	return 0


func _get_import_options(path, preset_index):
	return []


func _get_option_visibility(path, option_name, options):
	return true


func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
	var bytes = FileAccess.get_file_as_bytes(source_file)
	if bytes.is_empty():
		var error = FileAccess.get_open_error()
		MidiData._log("File not opened: %d" % error)
		return error
	var midi_data := MidiData.load_packed_byte_array(bytes)
	if midi_data == null:
		return ERR_PARSE_ERROR
	var result = ResourceSaver.save(midi_data, "%s.%s" % [save_path, _get_save_extension()])
	MidiData._log("MIDI save import result: %d" % result)
	return result
