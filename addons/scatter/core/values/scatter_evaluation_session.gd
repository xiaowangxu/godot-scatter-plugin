@tool
class_name ScatterEvaluationSession
extends RefCounted

var manual_claimed_targets: Dictionary[int, bool] = {}
var visited_targets: Dictionary[int, bool] = {}
var group_counts: Dictionary[int, int] = {}
var evaluation_cache: Dictionary[String, ScatterValue] = {}
var evaluation_cache_hits := 0
var error := ""
