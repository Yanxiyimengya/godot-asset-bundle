# GodotAssetBundle

GodotAssetBundle 是一个 Godot 编辑器导出插件，用于在项目导出时把指定目录下的资源拆分成独立的 `.pck` 资源包。它适合把 DLC、章节内容、皮肤、关卡包、可选美术资源等内容从主包中分离出来，减少主包体积，并让资源按需分发或加载。

## 特色

- 目录级资源分包：在某个目录中放置 `AssetBundle` 资源，即可把该目录作为一个资源包导出。
- 主包自动排除：被分包目录覆盖的资源会在主项目导出时跳过，避免同一资源同时进入主包和分包。
- 依赖自动收集：导出时会分析资源依赖，并把相关导入产物、`.import` 配置、remap 文件等一并写入分包。
- 场景与资源兼容：普通资源会被保存为导出资源，场景会按场景资源处理，尽量保持运行时路径可用。
- 原生 `.pck` 输出：分包使用 Godot 自带的 `PCKPacker` 生成，可以通过 Godot 标准资源包加载方式使用。

## 使用方式

1. 将 `addons/asset_bundle` 放入 Godot 项目的 `addons` 目录。
2. 在 Godot 编辑器中打开 `Project > Project Settings > Plugins`，启用 `GodotAssetBundle`。
3. 在需要分包的目录下创建一个 `AssetBundle` 资源文件。
4. 在 `AssetBundle` 资源中按需设置：
   - `enabled`：是否启用该资源包。
   - `export_enabled`：是否在导出时生成该资源包。
   - `pack_external_dependencies`：是否把当前分包目录外的依赖也打入该分包，默认开启。
5. 正常导出项目。插件会在导出目录下创建 `subpackages` 文件夹，并生成对应的 `.pck` 文件。
6. 运行时如需加载分包，可使用 Godot 标准 API：

```gdscript
ProjectSettings.load_resource_pack("res://subpackages/example.pck")
```

实际路径需要根据你的发布目录和平台打包方式调整。

## 目录结构

```text
addons/
  asset_bundle/
    AssetBundle.gd                  # 分包元数据资源
    AssetBundlePackUtils.gd          # 分包写入与依赖收集工具
    export_plugin.gd                 # 导出插件主体
    plugin.gd                        # 插件入口
    processors/
      AssetBundleResourceProcessor.gd
```

## 注意事项

- 插件负责导出分包，不负责自动下载或自动挂载分包。
- 分包资源应放在被 `AssetBundle` 所在的目录内。
- 如果资源依赖了分包目录外的文件，插件会尝试把必要依赖一起打入分包，除非 AssetBundle 的 `pack_external_dependencies` 属性被设置为 `false`。
- 如果关闭 `pack_external_dependencies`，分包只会收集当前分包目录内资源的依赖；目录外依赖需要由主包或其他分包提供。
- 导出的 `.pck` 文件名来自 `AssetBundle` 资源文件名。
