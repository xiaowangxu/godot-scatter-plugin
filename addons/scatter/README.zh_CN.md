# Scatter：Godot 4+ 原生 MultiMesh 散布工具

Scatter 只扩展 Godot 原生 `MultiMeshInstance3D`。配方作为 metadata 保存在目标节点上，生成结果直接写入它的 `MultiMesh`，不会向场景树添加 Scatter、Shape、Item 等自定义节点。

## 新版图编辑逻辑

每份配方只有一个不可删除的 **输出 Output** 节点，它有两个不同类型的输入：

- **Region（绿色）**：决定允许在哪里散布。Box、Sphere、Path、Paint Region 可通过 Union、Intersection、Subtract 组成最终区域。
- **Placement（紫色）**：决定如何生成及处理实例。布点节点、变换节点、过滤节点按真实连线求值。

只有连接到 Output 的分支会执行。拖动节点只改变画布布局，不会改变执行顺序；端口会阻止 Region/Placement 类型误连和循环依赖。旧版按列表排序的配方会在载入时自动迁移为这套连线图。

## 快速开始

1. 在 **项目 > 项目设置 > 插件** 中启用 **Scatter**。
2. 创建 `MultiMeshInstance3D`，给它的 `MultiMesh` 指定 Mesh。
3. 选中该节点，底部会自动打开 Scatter 编辑器。首次使用会创建 Box Region、Random Placement、随机旋转/缩放和 Output。
4. 从 **＋ 添加节点** 添加节点，把绿色 Region 与紫色 Placement 分别连到 Output。
5. 开启 **自动预览**，或点击 **生成预览**，在 3D 视口查看原生 MultiMesh 结果。

界面按钮与参数都提供中文 Tooltip；全局种子及节点独立种子保证结果可重复。

## Paint Region：多个独立绘制图层

1. 添加一个或多个 **绘制区域 Paint** 节点。
2. 选中某个 Paint 节点，或点击节点内的 **在视口绘制**。
3. 设置笔刷半径与碰撞层，点击 **绘制区域** 后在带物理碰撞的 3D 表面按左键绘制；使用 **擦除区域** 擦除当前图层。
4. 用 Union、Intersection、Subtract 连接多个 Paint/Shape 节点，再把组合结果接入 Output.Region。

每个 Paint 节点独立保存笔触，不再把所有手绘数据塞进一份全局列表。3D 视口会显示实时笔刷圆环、十字和法线方向；已绘制笔触持续显示轮廓。接入 Output 的 Region 使用高亮颜色，未连接的区域使用灰色提示。绘制/擦除支持 Godot UndoRedo。

Paint Region 表示“可散布区域”，实例密度由 Random/Grid/Poisson 等 Placement 节点决定。绘制厚度用于区域相交/相减，表面偏移可让生成点离开或贴近表面。

## 节点能力

- Region：Box、Sphere、Path、Paint；Union、Intersection、Subtract。
- Placement：Random、Grid、Poisson、沿边随机/等距/连续、Single、Merge Placement。
- 变换：Array、Transform、Position、Rotation、Scale、随机变换、随机旋转与角度步进、Look At、Snap、Relax、纹理聚类、物理投射与坡度过滤。
- 过滤：区域外/扣除区域过滤、随机移除。
- 数据：实例 Color、Custom Data、Proxy 配方与自动依赖重建。
- 工作流：确定性种子、自动预览、`.tres` 配方、原生 MultiMesh 接管、GraphEdit、小地图、Region Gizmo、可撤销视口绘制。

Path 点使用 `x,y,z; x,y,z; ...` 格式输入。一个 `MultiMesh` 只能引用一个 Mesh；多种资产应使用多个原生 `MultiMeshInstance3D`，并通过相同配方或 Proxy 共享规则。

## 与 Proton Scatter 的设计差异

本插件保留其 Region、Placement 与 Modifier 数据处理能力，但把编辑入口压缩到一个原生 MultiMesh 节点和一张数据流图中。场景不再需要 Scatter/Item/Shape 输出树，也不维护复制节点、粒子输出或编辑器线程生命周期；已生成的 MultiMesh buffer 本身就是可直接运行和保存的缓存。
