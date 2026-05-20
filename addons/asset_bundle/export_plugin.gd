extends EditorExportPlugin;

const AssetBundleResourceProcessor = preload("./processors/AssetBundleResourceProcessor.gd");

var bundles : Dictionary[String, AssetBundle] = {};
var bundle_files : Dictionary[String, bool] = {};
var bundle_resource_paths : Dictionary[String, PackedStringArray] = {};
var visited_bundle_scan_paths : Dictionary[String, bool] = {};
var resource_processors : Array[RefCounted] = [];

var export_path : String = "";

func _init() -> void:
	resource_processors.append(AssetBundleResourceProcessor.new());

func _get_name() -> String:
	return "   GodotAssetBundle";

func _export_begin(
		features: PackedStringArray, \
		is_debug: bool, \
		path: String, \
		flags: int) -> void:
	
	reset();
	export_path = path;
	_find_bundles("res://");

func _export_end() -> void:
	_export_bundles();
	reset();

func reset() -> void:
	bundles.clear();
	bundle_files.clear();
	bundle_resource_paths.clear();
	visited_bundle_scan_paths.clear();

func _export_file(path: String, type: String, features: PackedStringArray) -> void : 
	var need_skip : bool = false;
	for bundle_path in bundles:
		if (!_is_path_in_bundle(path, bundle_path)): continue;
		need_skip = true;
		if (!bundles[bundle_path].export_enabled): continue;
		if (bundle_files.has(path)): continue;
		
		if (!bundle_resource_paths.has(bundle_path)):
			bundle_resource_paths[bundle_path] = PackedStringArray();
		
		var resource_paths : PackedStringArray = bundle_resource_paths[bundle_path];
		if (resource_paths.has(path)): continue;
		
		resource_paths.append(path);
		bundle_resource_paths[bundle_path] = resource_paths;
	
	if (need_skip): skip();

func _find_bundles(path: String) -> void:
	var scan_key : String = _get_scan_key(path);
	if (visited_bundle_scan_paths.has(scan_key)): return;
	visited_bundle_scan_paths[scan_key] = true;
	
	var directory : DirAccess = DirAccess.open(path);
	if (directory == null): return;
	
	directory.list_dir_begin();
	
	var file_name : String = directory.get_next();
	while (file_name != ""):
		if (!file_name.begins_with(".")):
			var file_path : String = path.path_join(file_name);
			if (directory.current_is_dir()):
				_find_bundles(file_path);
			else:
				_try_add_bundle(file_path);
		
		file_name = directory.get_next();
	
	directory.list_dir_end();

func _try_add_bundle(path: String) -> void:
	var extension : String = path.get_extension();
	if (extension != "tres" && extension != "res"):
		return;
	
	var resource : Resource = ResourceLoader.load(path);
	if (!(resource is AssetBundle)):
		return;
	
	var bundle : AssetBundle = resource as AssetBundle;
	if (!bundle.enabled):
		return;
	
	var bundle_path : String = path.get_base_dir();
	bundle.name = path.get_file().get_basename();
	
	bundles[bundle_path] = bundle;
	bundle_resource_paths[bundle_path] = PackedStringArray();
	bundle_files[path] = true;

func _export_bundles() -> void:
	if (export_path.is_empty()): return;
	if (bundles.is_empty()): return;
	
	var has_export_enabled_bundle : bool = false;
	for bundle_path in bundles:
		if (bundles[bundle_path].export_enabled):
			has_export_enabled_bundle = true;
			break;
	if (!has_export_enabled_bundle): return;
	
	var export_directory : String = export_path.get_base_dir();
	if (DirAccess.dir_exists_absolute(export_path)):
		export_directory = export_path;
	
	var subpackage_directory : String = export_directory.path_join("subpackages");
	var error : int = DirAccess.make_dir_recursive_absolute(subpackage_directory);
	if (error != OK):
		push_error("Failed to create subpackage export directory: %s" % subpackage_directory);
		return;
	
	for bundle_path in bundles:
		if (!bundles[bundle_path].export_enabled): continue;
		_export_bundle(bundle_path, bundles[bundle_path], subpackage_directory);

func _export_bundle(bundle_path: String, bundle: AssetBundle, subpackage_directory: String) -> void:
	var package_name : String = bundle.name + ".pck";
	var package_path : String = subpackage_directory.path_join(package_name);
	var temp_directory : String = subpackage_directory.path_join("." + package_name.get_basename() + "_temp");
	
	_remove_directory(temp_directory);
	
	var error : int = DirAccess.make_dir_recursive_absolute(temp_directory);
	if (error != OK):
		push_error("Failed to create subpackage temporary directory: %s" % temp_directory);
		return;
	
	if (FileAccess.file_exists(package_path)):
		DirAccess.remove_absolute(package_path);
	
	var packer : PCKPacker = PCKPacker.new();
	error = packer.pck_start(package_path);
	if (error != OK):
		push_error("Failed to create subpackage: %s" % package_path);
		_remove_directory(temp_directory);
		return;
	
	var packed_paths : Dictionary[String, bool] = {};
	var resource_paths : PackedStringArray = bundle_resource_paths.get(bundle_path, PackedStringArray());
	for resource_path in resource_paths:
		_pack_resource_path(packer, resource_path, temp_directory, packed_paths, bundle_path, bundle);
	
	error = packer.flush();
	if (error != OK):
		push_error("Failed to write subpackage: %s" % package_path);
	
	_remove_directory(temp_directory);

func _pack_resource_path(
		packer: PCKPacker, \
		resource_path: String, \
		temp_directory: String, \
		packed_paths: Dictionary[String, bool], \
		bundle_path: String, \
		bundle: AssetBundle) -> void:
	
	var resource : Resource = ResourceLoader.load(resource_path);
	if (resource == null):
		push_warning("Skipping subpackage resource that could not be loaded: %s" % resource_path);
		return;
	
	for processor in resource_processors:
		if (processor.can_process(resource_path, resource)):
			processor.pack_resource(
					packer, \
					resource_path, \
					resource, \
					temp_directory, \
					packed_paths, \
					bundle_path, \
					bundle.pack_external_dependencies);
			return;

func _remove_directory(path: String) -> void:
	if (!DirAccess.dir_exists_absolute(path)): return;
	
	var directory : DirAccess = DirAccess.open(path);
	if (directory == null): return;
	directory.include_hidden = true;
	
	var file_paths : PackedStringArray = [];
	var directory_paths : PackedStringArray = [];
	
	directory.list_dir_begin();
	
	var file_name : String = directory.get_next();
	while (file_name != ""):
		var file_path : String = path.path_join(file_name);
		if (directory.current_is_dir() && !directory.is_link(file_name)):
			directory_paths.append(file_path);
		else:
			file_paths.append(file_path);
		
		file_name = directory.get_next();
	
	directory.list_dir_end();
	
	for directory_path in directory_paths:
		_remove_directory(directory_path);
	
	for file_path in file_paths:
		DirAccess.remove_absolute(file_path);
	
	DirAccess.remove_absolute(path);

func _is_path_in_bundle(path: String, bundle_path: String) -> bool:
	var bundle_directory : String = bundle_path.path_join("");
	if (!bundle_directory.ends_with("/")):
		bundle_directory += "/";
	return path.begins_with(bundle_directory);

func _get_scan_key(path: String) -> String:
	var global_path : String = ProjectSettings.globalize_path(path);
	if (global_path.is_empty()):
		return path;
	
	return global_path;
