@tool
class_name ScatterBuildResult
extends RefCounted

var ok := true
var error := ""
var instances := ScatterInstanceBuffer.new()
var group_counts: Dictionary[int, int] = {}


static func failure(message: String) -> ScatterBuildResult:
	var result := ScatterBuildResult.new()
	result.ok = false
	result.error = message
	return result
