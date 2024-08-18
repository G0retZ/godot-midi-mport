@tool
extends EditorPlugin


var midi_import_plugin
var midi_save_plugin
var midi_load_plugin


func _enter_tree():
	midi_import_plugin = preload("midi_import_plugin.gd").new()
	midi_save_plugin = preload("midi_save_plugin.gd").new()
	midi_load_plugin = preload("midi_load_plugin.gd").new()
	add_export_plugin(midi_import_plugin)
	ResourceSaver.add_resource_format_saver(midi_save_plugin)
	ResourceLoader.add_resource_format_loader(midi_load_plugin)


func _exit_tree():
	remove_export_plugin(midi_import_plugin)
	ResourceSaver.add_resource_format_saver(midi_save_plugin)
	ResourceLoader.add_resource_format_loader(midi_load_plugin)
	midi_import_plugin = null
	midi_save_plugin = null
	midi_load_plugin = null
