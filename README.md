# Scatter Plugin

面向 Godot 4.7+ 的原生 `MultiMeshInstance3D` 可视化散布编辑器。插件不增加场景节点；它在编辑器中计算实例数据并写入 MultiMesh，运行时只使用已经保存的 buffer。

- [中文文档](addons/scatter/README.zh_CN.md)
- [English documentation](addons/scatter/README.md)
- 示例：`res://addons/scatter/demo/scatter_demo.tscn`

这是一次断代架构，不读取早期 Scatter Group / Scatter Set recipe。
