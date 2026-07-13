# Scatter for Godot 4.7+

Scatter is an editor-only visual instance-data builder attached directly to a native `MultiMeshInstance3D`. It adds no scene nodes. A typed `ScatterGraph` is stored as metadata and Build writes the result to the native `MultiMesh`; at runtime the saved buffer is used without evaluating the graph.

## Workflow

1. Select a `MultiMeshInstance3D` and open the Scatter bottom panel.
2. Connect Region and Placement streams to one or more Scatter Group nodes.
3. Connect each Scatter Set to Final Output.
4. Build the graph, or enable Auto Build.

The graph editor uses Godot's native `GraphEdit` and `GraphNode` styling. It supports selection, Delete, right-click commands, copy/cut/paste, duplicate, connection editing, node Enable controls, a minimap, and direct-property UndoRedo.

## Node library

- Region: Box, Sphere, Path, Paint, Union, Intersection, and Subtract.
- Placement: Random, Grid, Poisson, random/even/continuous edge placement, Single, and Merge Placement.
- Transform: Array, Transform, Position, Rotation, Scale, Random Transform, Random Rotation, Look At, Snap, Relax, Clusterize, and Project.
- Filter and data: Remove Outside, Remove Random, Proxy Graph, Random Color, and Random Custom Data.
- Output: Scatter Group and Final Output. Final Output accepts ordered, variadic Scatter Sets.

Selecting a Path node makes it the active 3D viewport editor. Its native viewport toolbar switches between moving handles, adding points, deleting points, and closing the path; selecting another graph node or clearing the selection exits path editing. Paint Region follows the same selection-driven activation model and stores typed stroke resources. Its native viewport toolbar contains Paint/Erase modes, brush radius, layer clearing, and the collision mask; the viewport provides brush preview, persistent region outlines, and UndoRedo. Proxy Graph can consume another native `MultiMeshInstance3D` recipe and detects dependency cycles.

## Public extension API

Custom addons can register model and editor-view scripts without modifying Scatter:

```gdscript
func _enter_tree() -> void:
    ScatterNodeRegistry.register_node(MyScatterNode, MyScatterNodeView)

func _exit_tree() -> void:
    ScatterNodeRegistry.unregister_node(&"my_scatter_node")
```

`ScatterNode` owns typed parameters, stable `StringName` ports, validation, evaluation, disabled behavior, seed policy, and preview geometry. `ScatterNodeView` owns only GraphNode layout and editor interaction, including overridable viewport-tool activation hooks. Core code has no Editor API dependency.

Recipes are native `.tres` `ScatterGraph` resources. This architecture intentionally does not import the earlier Dictionary recipe formats.

See `res://addons/scatter/demo/scatter_demo.tscn` for a saved native MultiMesh buffer and typed recipe.
