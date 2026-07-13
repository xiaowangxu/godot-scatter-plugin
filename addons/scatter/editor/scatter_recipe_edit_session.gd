@tool
class_name ScatterRecipeEditSession
extends RefCounted

var recipe_path := ""
var source_graph: ScatterGraph
var working_graph: ScatterGraph
var dirty := false


static func create(source: ScatterGraph) -> ScatterRecipeEditSession:
	if source == null or source.resource_path.is_empty():
		return null
	var session := ScatterRecipeEditSession.new()
	session.recipe_path = source.resource_path
	session.source_graph = source
	session.working_graph = source.duplicate_graph()
	session.working_graph.resource_local_to_scene = true
	return session


func mark_dirty() -> void:
	dirty = true


func save() -> Error:
	if working_graph == null or recipe_path.is_empty():
		return ERR_INVALID_PARAMETER
	var snapshot := working_graph.duplicate_graph()
	snapshot.resource_local_to_scene = false
	var error := ResourceSaver.save(snapshot, recipe_path)
	if error != OK:
		return error
	var refreshed := ResourceLoader.load(
		recipe_path,
		"ScatterGraph",
		ResourceLoader.CACHE_MODE_REPLACE,
	) as ScatterGraph
	if refreshed == null:
		refreshed = ResourceLoader.load(
			recipe_path,
			"ScatterGraph",
			ResourceLoader.CACHE_MODE_IGNORE,
		) as ScatterGraph
	if refreshed == null:
		return ERR_CANT_OPEN
	source_graph = refreshed
	dirty = false
	return OK
