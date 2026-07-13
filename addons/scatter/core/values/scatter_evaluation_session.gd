@tool
class_name ScatterEvaluationSession
extends RefCounted

var manual_claimed_targets: Dictionary[int, bool] = {}
var visited_targets: Dictionary[int, bool] = {}
var group_counts: Dictionary[int, int] = {}
var error := ""
