@tool
extends EditorPlugin;

const EXPORT_PLUGIN : GDScript = preload("./export_plugin.gd");

var _export_plugin_instance : EditorExportPlugin;

func _init() -> void:
	_export_plugin_instance = EXPORT_PLUGIN.new();

func _enable_plugin() -> void: pass;
func _disable_plugin() -> void: pass;

func _enter_tree() -> void:
	self.add_export_plugin(_export_plugin_instance);

func _exit_tree() -> void:
	self.remove_export_plugin(_export_plugin_instance);
