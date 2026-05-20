extends RefCounted;

const AssetBundlePackUtils = preload("../AssetBundlePackUtils.gd");

func can_process(_resource_path: String, _resource: Resource) -> bool:
	return true;

func pack_resource(
		packer: PCKPacker, \
		resource_path: String, \
		resource: Resource, \
		temp_directory: String, \
		packed_paths: Dictionary[String, bool], \
		bundle_path: String, \
		pack_external_dependencies: bool) -> void:
	if (AssetBundlePackUtils.has_import_file(resource_path)) : 
		AssetBundlePackUtils.pack_import_dependencies(packer, resource_path, temp_directory, packed_paths);
	else: 
		AssetBundlePackUtils.pack_remapped_resource(packer, resource_path, resource, temp_directory, packed_paths);
	AssetBundlePackUtils.pack_resource_dependencies(
			packer, \
			resource_path, \
			temp_directory, \
			packed_paths, \
			bundle_path, \
			pack_external_dependencies);
