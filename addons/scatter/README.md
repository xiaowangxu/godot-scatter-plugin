# Scatter for Godot 4+

Scatter is a visual instance-data editor attached directly to a native `MultiMeshInstance3D`. The recipe is stored in node metadata and the result is written to its native `MultiMesh`; no custom scene nodes are required.

## Graph model

Every recipe can contain multiple **Group** nodes and one non-deletable **Final Output**:

- A **Group** receives one **Region** (green) and one **Placement** stream (purple), then emits one amber **Scatter Set**.
- **Final Output** accepts any number of Scatter Sets and concatenates them into the native MultiMesh buffer in port order. One spare input socket is always shown.
- Region sources include Box, Sphere, Path and Paint and can be combined with Union, Intersection and Subtract.

Random, Grid, Poisson, Single, Edge and Proxy creators are output-only. Transform and filter nodes remain input/output processors; multiple Placement streams are combined explicitly with **Merge Placement**.

Connections are persistent data, not decorative list-order wires. Ports reject type mismatches and cycles. Moving a node only changes canvas layout. Version 1 list recipes and version 2 Output nodes migrate automatically. The compact node UI keeps descriptions in tooltips and shows only ports, parameters, enable/delete controls and instance counts.

## Paint Region layers

Add any number of Paint Region nodes. Select or activate one node, choose Paint/Erase in the toolbar, then draw on a collidable 3D surface. Each node stores an independent stroke layer that can be combined with other Region nodes.

The viewport shows a live brush ring, cross and surface normal plus persistent stroke outlines. Connected Region sources are highlighted; disconnected sources are dimmed. Painting is UndoRedo-aware. Paint controls the allowed area, while Random/Grid/Poisson Placement nodes control density.

## Features

- Regions: Box, Sphere, Path, Paint, Union, Intersection, Subtract.
- Placement: random, grid, Poisson disk, random/even/continuous edge placement, single, and merge.
- Processing: array, transform/position/rotation/scale, random transform/rotation, look-at, snap, relax, texture clustering, physics projection and slope filtering.
- Filtering and data: outside/subtraction filtering, random removal, instance color, custom data, and proxy recipes.
- Workflow: deterministic global/per-node seeds, automatic preview, `.tres` recipes, native MultiMesh adoption, GraphEdit minimap, Region gizmos and undoable painting.

Select a `MultiMeshInstance3D` to open the bottom panel. The starter graph contains a Box Region and a Random Placement chain connected to one Group, whose Scatter Set feeds Final Output. All controls include Chinese labels and tooltips.

One `MultiMesh` can reference one Mesh. Use one native `MultiMeshInstance3D` per asset and share recipes or distributions through Proxy when scattering multiple assets.
