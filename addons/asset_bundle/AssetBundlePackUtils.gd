extends RefCounted;

## 打包 remap 资源/场景
static func pack_remapped_resource(
		packer: PCKPacker, \
		resource_path: String, \
		resource: Resource, \
		temp_directory: String, \
		packed_paths: Dictionary[String, bool]) -> void:
	
	if (resource_path.is_empty()):
		push_warning("Skipping subpackage resource without resource_path: %s" % resource);
		return;
	
	var package_resource_path : String = _get_exported_file_path(resource_path, "res");
	if (is_scene_resource(resource_path, resource)):
		package_resource_path = _get_exported_file_path(resource_path, "scn");
	
	if (!packed_paths.has(package_resource_path)):
		var temp_resource_path : String = \
				temp_directory.path_join(
				_get_temp_resource_file_name(package_resource_path)
				);
		var flags : int = ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES | ResourceSaver.FLAG_COMPRESS;
		var error : int = ResourceSaver.save(resource, temp_resource_path, flags);
		if (error != OK):
			push_error("Failed to serialize subpackage resource: %s" % resource_path);
			return;
		
		error = packer.add_file(package_resource_path, temp_resource_path);
		if (error != OK):
			push_error("Failed to add subpackage resource: %s" % package_resource_path);
			_remove_file(temp_resource_path);
			return;
		
		packed_paths[package_resource_path] = true;
	
	_pack_resource_remap(packer, resource_path, package_resource_path, temp_directory, packed_paths);

## 打包资源依赖
static func pack_resource_dependencies(
		packer: PCKPacker, \
		resource_path: String, \
		temp_directory: String, \
		packed_paths: Dictionary[String, bool], \
		bundle_path: String = "", \
		pack_external_dependencies: bool = true) -> void:
	
	if (resource_path.is_empty()): return;
	
	for dependency in ResourceLoader.get_dependencies(resource_path):
		var dependency_path : String = _get_dependency_path(dependency);
		if (dependency_path.is_empty()): continue;
		if (!pack_external_dependencies && !_is_dependency_in_bundle(dependency, dependency_path, bundle_path)): continue;
		
		if (has_import_file(dependency_path)):
			pack_import_dependencies(packer, dependency_path, temp_directory, packed_paths);
		elif (dependency_path.begins_with("res://.godot/imported/")):
			pack_project_file(packer, dependency_path, packed_paths);

## 读取 .import 文件中的导入依赖，并打包依赖项
static func pack_import_dependencies(
		packer: PCKPacker, \
		resource_path: String, \
		temp_directory: String, \
		packed_paths: Dictionary[String, bool]) -> void:
	
	if (!has_import_file(resource_path)): return;
	
	var import_path : String = resource_path + ".import";
	
	var config : ConfigFile = ConfigFile.new();
	var error : int = config.load(import_path);
	if (error != OK):
		push_warning("Failed to read import config: %s" % import_path);
		return;
	
	if (!packed_paths.has(import_path)):
		var runtime_config : ConfigFile = ConfigFile.new();
		if (config.has_section("remap")):
			for key in config.get_section_keys("remap"):
				runtime_config.set_value("remap", key, config.get_value("remap", key));
		
		var temp_import_path : String = temp_directory.path_join(_get_temp_resource_file_name(import_path));
		error = runtime_config.save(temp_import_path);
		if (error != OK):
			push_error("Failed to create runtime import file: %s" % import_path);
			return;
		
		error = packer.add_file(import_path, temp_import_path);
		if (error != OK):
			push_error("Failed to add runtime import file: %s" % import_path);
			_remove_file(temp_import_path);
			return;
		
		packed_paths[import_path] = true;
	
	var imported_paths : Array[String] = [];
	if (config.has_section("remap")):
		for key in config.get_section_keys("remap"):
			if (key == "path" || key.begins_with("path.")):
				_append_imported_file_paths(imported_paths, config.get_value("remap", key));
	
	if (config.has_section_key("deps", "dest_files")):
		_append_imported_file_paths(imported_paths, config.get_value("deps", "dest_files"));
	
	for imported_path in imported_paths:
		pack_project_file(packer, imported_path, packed_paths);

## 打包项目目录中的文件
static func pack_project_file(
		packer: PCKPacker, \
		path: String, \
		packed_paths: Dictionary[String, bool]) -> void:
	
	if (path.is_empty()): return;
	if (!path.begins_with("res://")): return;
	if (packed_paths.has(path)): return;
	
	var source_path : String = ProjectSettings.globalize_path(path);
	if (!FileAccess.file_exists(source_path)):
		push_warning("Subpackage dependency file does not exist: %s" % path);
		return;
	
	var error : int = packer.add_file(path, source_path);
	if (error != OK):
		push_error("Failed to add subpackage dependency: %s" % path);
		return;
	
	packed_paths[path] = true;

## 判断是否为场景文件
static func is_scene_resource(resource_path: String, resource: Resource) -> bool:
	if (resource is PackedScene): return true;
	if (resource_path.is_empty()): return false;
	
	var extension : String = resource_path.get_extension().to_lower();
	return extension == "tscn" || extension == "scn";

## 检查当前文件是否存在 .import 导入文件
static func has_import_file(path: String) -> bool:
	if (path.is_empty()): return false;
	return FileAccess.file_exists(path + ".import");

## 打包资源的 remap 文件
static func _pack_resource_remap(
		packer: PCKPacker, \
		resource_path: String, \
		package_resource_path: String, \
		temp_directory: String, \
		packed_paths: Dictionary[String, bool]) -> void:
	
	var remap_path : String = resource_path + ".remap";
	if (packed_paths.has(remap_path)): return;
	
	var temp_remap_path : String = temp_directory.path_join(_get_temp_resource_file_name(remap_path));
	var config : ConfigFile = ConfigFile.new();
	config.set_value("remap", "path", package_resource_path);
	
	var error : int = config.save(temp_remap_path);
	if (error != OK):
		push_error("Failed to create subpackage remap file: %s" % resource_path);
		return;
	
	error = packer.add_file(remap_path, temp_remap_path);
	if (error != OK):
		push_error("Failed to add subpackage remap file: %s" % remap_path);
		_remove_file(temp_remap_path);
		return;
	
	packed_paths[remap_path] = true;

static func _append_imported_file_paths(imported_paths: Array[String], value: Variant) -> void:
	if (value is String):
		if (!value.is_empty() && value.begins_with("res://") && !imported_paths.has(value)):
			imported_paths.append(value);
	elif (value is Array):
		for file_path in value:
			var path : String = str(file_path);
			if (path.is_empty()): continue;
			if (!path.begins_with("res://")): continue;
			if (imported_paths.has(path)): continue;
			imported_paths.append(path);
	elif (value is PackedStringArray):
		for file_path in value:
			if (file_path.is_empty()): continue;
			if (!file_path.begins_with("res://")): continue;
			if (imported_paths.has(file_path)): continue;
			imported_paths.append(file_path);

static func _get_dependency_path(dependency: String) -> String:
	var parts : PackedStringArray = dependency.split("::");
	for index in range(parts.size() - 1, -1, -1):
		var part : String = parts[index];
		if (part.begins_with("res://")):
			return part;
	return "";

static func _is_dependency_in_bundle(dependency: String, dependency_path: String, bundle_path: String) -> bool:
	if (_is_path_in_bundle(dependency_path, bundle_path)):
		return true;

	for part in dependency.split("::"):
		if (!part.begins_with("res://")): continue;
		if (part.begins_with("res://.godot/imported/")): continue;
		if (_is_path_in_bundle(part, bundle_path)):
			return true;

	return false;

static func _get_exported_file_path(resource_path: String, extension: String) -> String:
	var resource_name : String = resource_path.get_file().get_basename();
	var resource_hash : String = resource_path.md5_text();
	
	if (resource_name.is_empty()):
		resource_name = "resource";
	
	return "res://.godot/exported/subpackages/export-%s-%s.%s" % [resource_hash, resource_name, extension];

static func _is_path_in_bundle(path: String, bundle_path: String) -> bool:
	if (bundle_path.is_empty()): return true;
	var bundle_directory : String = bundle_path.path_join("");
	if (!bundle_directory.ends_with("/")):
		bundle_directory += "/";
	return path.begins_with(bundle_directory);

static func _get_temp_resource_file_name(resource_path: String) -> String:
	var file_name : String = resource_path.trim_prefix("res://");
	file_name = file_name.replace("/", "__");
	file_name = file_name.replace("\\", "__");
	file_name = file_name.replace(":", "_");
	return file_name;

static func _remove_file(path: String) -> void:
	if (FileAccess.file_exists(path)):
		DirAccess.remove_absolute(path);
