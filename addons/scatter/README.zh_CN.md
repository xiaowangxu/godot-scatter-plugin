# Godot 4.7+ Scatter

Scatter 直接扩展原生 `MultiMeshInstance3D`，不创建自定义场景节点。Recipe 只在编辑器中求值；Build 把结果写入 MultiMesh，游戏运行时直接使用已保存的 buffer。

## 使用流程

1. 选择 `MultiMeshInstance3D`。
2. 点击“Configure Scatter”新建 recipe，或点击“Load Recipe”引用 `.tres`。
3. Shape 显式连接 Random、Grid、Poisson；Path 显式连接 Path Random/Even/Continuous；Instances 最终直接连接 Final Output。
4. Build 生成实例。只有点击 Save Recipe 或在面板中按 Ctrl+S 才会保存工作副本。
5. Detach 只删除 metadata，不修改 recipe 文件和已有 MultiMesh buffer。

新架构没有 Scatter Group 和 Scatter Set，也不兼容旧开发版本 recipe。

Box 与 Sphere 使用确定性直接采样；Boolean Shape 在组合 AABB 内统一拒绝采样，因此 Union 按体积保持均匀密度。Poisson 使用真正的确定性 3D Bridson 算法。Path 按总弧长采样，Path Tube Region 可把一维 Path 转换为三维 Region。

端口类型支持多父类型和 capability。图在 Build 前经过编译，验证 Final Output、端口、类型、连接顺序和循环，并生成稳定拓扑计划；单次 Build 内每个节点只执行一次。Warning 可以写入部分结果，Error 才阻止写入。

外部 addon 使用 `ScatterExtensionRegistry.register_node(model, view, editor_extension)` 注册节点。Gizmo 与视口工具由最后选中节点的 Editor Extension 提供。
