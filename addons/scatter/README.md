# Scatter for Godot 4+

Scatter is a visual instance-data editor attached directly to a native `MultiMeshInstance3D`. The recipe is stored in node metadata and the result is written to its native `MultiMesh`; no custom scene nodes are required.

## Graph model

Every recipe has one non-deletable **Output** node:

- **Region** (green) defines where scattering is allowed. Box, Sphere, Path and Paint Region sources can be combined with Union, Intersection and Subtract.
- **Placement** (purple) defines how instances are created and processed. Only the branch connected to Output is evaluated.

Connections are persistent data, not decorative list-order wires. Ports reject type mismatches and cycles. Moving a node only changes canvas layout. Version 1 list recipes migrate automatically.

## Paint Region layers

Add any number of Paint Region nodes. Select or activate one node, choose Paint/Erase in the toolbar, then draw on a collidable 3D surface. Each node stores an independent stroke layer that can be combined with other Region nodes.

The viewport shows a live brush ring, cross and surface normal plus persistent stroke outlines. Connected Region sources are highlighted; disconnected sources are dimmed. Painting is UndoRedo-aware. Paint controls the allowed area, while Random/Grid/Poisson Placement nodes control density.

## Features

- Regions: Box, Sphere, Path, Paint, Union, Intersection, Subtract.
- Placement: random, grid, Poisson disk, random/even/continuous edge placement, single, and merge.
- Processing: array, transform/position/rotation/scale, random transform/rotation, look-at, snap, relax, texture clustering, physics projection and slope filtering.
- Filtering and data: outside/subtraction filtering, random removal, instance color, custom data, and proxy recipes.
- Workflow: deterministic global/per-node seeds, automatic preview, `.tres` recipes, native MultiMesh adoption, GraphEdit minimap, Region gizmos and undoable painting.

Select a `MultiMeshInstance3D` to open the bottom panel. The starter graph contains a Box Region and a Random Placement chain connected to Output. All controls include Chinese-first labels and tooltips.

One `MultiMesh` can reference one Mesh. Use one native `MultiMeshInstance3D` per asset and share recipes or distributions through Proxy when scattering multiple assets.
