@tool
class_name ScatterRecipeIO
extends RefCounted


static func save_graph(graph: ScatterGraph, path: String) -> Error:
	if graph == null or path.is_empty():
		return ERR_INVALID_PARAMETER
	var recipe := graph.duplicate_graph()
	recipe.resource_local_to_scene = false
	return ResourceSaver.save(recipe, path)


static func load_graph(path: String) -> ScatterGraph:
	if path.is_empty() or not ResourceLoader.exists(path, "ScatterGraph"):
		return null
	var loaded := ResourceLoader.load(path, "ScatterGraph", ResourceLoader.CACHE_MODE_IGNORE)
	if not loaded is ScatterGraph:
		return null
	var graph := (loaded as ScatterGraph).duplicate_graph()
	graph.resource_local_to_scene = true
	return graph
