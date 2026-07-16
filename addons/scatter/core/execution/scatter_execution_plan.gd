@tool
class_name ScatterExecutionPlan
extends RefCounted

var graph: ScatterGraph
var index: ScatterGraphIndex
var final_node_id := -1
var topological_node_ids: Array[int] = []
var ordered_node_ids: Array[int] = []
var diagnostics: Array[ScatterDiagnostic] = []


func has_errors() -> bool:
	for diagnostic in diagnostics:
		if diagnostic.severity == ScatterDiagnostic.Severity.ERROR:
			return true
	return false
