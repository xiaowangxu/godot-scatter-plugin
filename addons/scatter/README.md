# Scatter for Godot 4.7+

Scatter is an editor-only instance-data builder attached directly to native `MultiMeshInstance3D`. It adds no scene nodes and performs no graph evaluation at runtime.

## Workflow

1. Select a `MultiMeshInstance3D`.
2. Use **Configure Scatter** for a new recipe, or **Load Recipe** to reference a `.tres` graph.
3. Connect a Shape to Random, Grid, or Poisson; connect Path to a Path sampler; connect resulting Instances to Final Output.
4. Build to write the MultiMesh buffer. Use **Save Recipe** or Ctrl+S to persist the working graph. Editing never silently saves the recipe.
5. Detach removes only metadata. It preserves the recipe resource and the generated MultiMesh buffer.

Final Output accepts ordered variadic Instances inputs directly. Scatter Group and Scatter Set no longer exist.

## Value system

Ports use stable `StringName` value types and a multiple-parent type registry:

```text
value
├── shape
│   └── region
│       └── regular_region
├── path
├── direct_sampleable
│   ├── regular_region
│   └── path
└── instances
```

Paths are one-dimensional arc-length curves. Path Tube Region converts a Path to a volume Shape. Shape Transform applies composable MultiMesh-local position, rotation, and scale to either a Shape or Path while preserving the explicit value type. Boolean operators accept Shape and return Shape, so their Random sampling uses deterministic rejection sampling over the combined local AABB. Regular Box and Sphere regions use exact direct sampling. Poisson uses deterministic 3D Bridson sampling.

Every stored instance transform is MultiMesh Local. Shape and Path sources may be authored in Global or Local space; Global values are frozen into target-local values during evaluation. Instance space is available only on Instances transform nodes.

## Extension API

External addons register a model, GraphNode view, and editor extension together:

```gdscript
func _enter_tree() -> void:
    ScatterValueTypeRegistry.register_type(&"my_value", [&"value"], Color.CORNFLOWER_BLUE)
    ScatterExtensionRegistry.register_node(MyNode, MyNodeView, MyNodeEditorExtension)

func _exit_tree() -> void:
    ScatterExtensionRegistry.unregister_node(&"my_node")
    ScatterValueTypeRegistry.unregister_type(&"my_value")
```

`ScatterGraphCompiler` validates ports, subtype assignment, variadic order, the unique Final Output, and cycles before producing a stable topological plan. Each node evaluates once per Build and may return multiple named outputs through `ScatterNodeOutputs`. Structured warnings allow partial output; errors prevent MultiMesh writes.

The editor extension controls the selected-node gizmo and optional viewport tool. The shared gizmo host does not branch on concrete node types.

## Tests

Run the headless suite with Godot 4.7:

```text
godot --headless --path . --script res://addons/scatter/tests/run_all.gd
```
