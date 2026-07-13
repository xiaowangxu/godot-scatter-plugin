# Scatter：Godot 4.7+ 原生 MultiMesh 散布工具

Scatter 是一个只在编辑器中求值的可视化实例数据工具。它直接附着到原生 `MultiMeshInstance3D`，不会向场景树添加任何自定义节点。强类型 `ScatterGraph` 以 metadata 保存；点击生成后，结果写入原生 `MultiMesh`。游戏运行时只使用已经保存的 buffer，不会重新计算散布图。

## 使用方式

1. 选中一个 `MultiMeshInstance3D`，打开底部 Scatter 面板。
2. 将 Region 与 Placement 数据流连接到一个或多个 Scatter Group。
3. 将各 Group 输出的 Scatter Set 连接到 Final Output。
4. 点击 Build，或者启用 Auto Build。

图编辑器使用 Godot 原生 `GraphEdit` / `GraphNode` 样式，支持 Del 删除、右键菜单、复制、剪切、粘贴、重复、连接编辑、标题栏 Enable、缩略图以及细粒度 UndoRedo。

## 节点

- Region：Box、Sphere、Path、Paint、Union、Intersection、Subtract。
- Placement：Random、Grid、Poisson、三种边缘布点、Single、Merge Placement。
- Transform：Array、Transform、Position、Rotation、Scale、Random Transform、Random Rotation、Look At、Snap、Relax、Clusterize、Project。
- Filter / Data：Remove Outside、Remove Random、Proxy Graph、Random Color、Random Custom Data。
- Output：Scatter Group 与 Final Output。Final Output 按稳定顺序接收任意数量的 Scatter Set。

Paint Region 使用强类型笔触资源，3D 视口支持绘制、擦除、笔刷预览、持久轮廓和撤销重做。Proxy Graph 可以读取另一个原生 `MultiMeshInstance3D` 的配方，并检测代理循环。

## 扩展节点

外部 addon 可以通过公开注册表添加自己的模型和视图：

```gdscript
func _enter_tree() -> void:
	ScatterNodeRegistry.register_node(MyScatterNode, MyScatterNodeView)

func _exit_tree() -> void:
	ScatterNodeRegistry.unregister_node(&"my_scatter_node")
```

`ScatterNode` 负责参数、稳定端口、验证、计算、禁用策略、Seed 和预览几何；`ScatterNodeView` 只负责 GraphNode 布局与编辑器交互。核心层不引用 Editor API。

配方文件是原生 `.tres` `ScatterGraph` 资源。本次架构不读取或迁移早期 Dictionary 配方格式。

示例场景：`res://addons/scatter/demo/scatter_demo.tscn`。
