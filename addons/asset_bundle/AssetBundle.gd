@icon("./images/asset_bundle.svg")
@tool
class_name AssetBundle extends Resource;
## Metadata for using the current folder as an asset bundle

@export var enabled : bool = true; ## Whether this asset bundle is enabled
@export var export_enabled : bool = true; ## Whether this asset bundle is exported

var name : String = "";

var resources : Array[Resource] = [];
