@icon("./images/asset_bundle.svg")
@tool
class_name AssetBundle extends Resource;

## 表示当前文件夹作为资源包的元数据信息

@export var enabled : bool = true; ## 是否启用该资源包
@export var export_enabled : bool = true; ## 是否导出该资源包
@export var pack_external_dependencies : bool = true; ## 是否打包当前资源包目录外的依赖

var name : String = "";

var resources : Array[Resource] = [];
