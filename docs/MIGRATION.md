# Internal path migration

The refactor preserves public `class_name` APIs and serialized script UIDs, but source paths were reorganized because this repository is still explicitly pre-stable.

| Previous path | Current path |
| --- | --- |
| `core/services/scatter_graph_*` and `scatter_build_service.gd` | `core/execution/` |
| execution context/result/input/output files under `core/values/` | `core/execution/` |
| `core/services/scatter_connection_service.gd` | `core/graph/` |
| instance algorithms under `core/services/` | `core/operations/` |
| graph attachment and MultiMesh writer under `core/services/` | `core/io/` |
| `core/regions/` | `core/geometry/` |
| editor session/context/undo files at `editor/` root | `editor/application/` |
| panel/sidebar/toolbar/status files at `editor/` root | `editor/ui/` |
| `editor/paint/` | `editor/tools/` |
| `editor/views/<node category>/` | `editor/graph/views/` |

External addons should prefer registered `class_name` types over preloading Scatter's internal files. Custom nodes continue to register through `ScatterExtensionRegistry`.

`ScatterProxyNode` and its scene-target dependency system were removed. Recipes that contain the legacy `proxy` node are not migrated automatically and must be rebuilt without cross-Target graph references.
