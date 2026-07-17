@tool
extends ScatterNode

@export_category("Metadata")
@export_group("Measurements", "metadata_")
@export_range(0.1, 100.0, 0.5, "or_less", "or_greater", "exp", "suffix:m") var metadata_distance := 2.0
@export_range(0.0, 360.0, 0.5, "radians_as_degrees") var metadata_angle := PI / 2.0

@export_subgroup("Choices", "metadata_choice_")
@export_enum("Ten:10", "Twenty:20") var metadata_choice_integer := 20
@export_enum("Alpha", "Beta") var metadata_choice_string := "Beta"

@export_group("")
@export var plain_text := "plain"

@export_group("Empty", "empty_")
@export_storage var empty_hidden := 1

@export_category("Advanced")
@export_group("Flags")
@export_flags("First:1", "Third:4") var flags := 5

@export_group("Text")
@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, "First,Second") var suggestion := "Custom"
@export_placeholder("Enter a label") var placeholder := ""
@export_multiline var multiline := "Line one\nLine two"
@export_custom(PROPERTY_HINT_PASSWORD, "") var password := "secret"
@export_file("*.png", "*.jpg") var file_path := "res://icon.svg"
@export_dir var directory_path := "res://"
@export_custom(PROPERTY_HINT_SAVE_FILE, "*.tres") var save_path := "res://metadata.tres"

@export_group("Display")
@export_custom(
	PROPERTY_HINT_NONE,
	"suffix:m",
	PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY,
) var readonly_distance := 5.0
@export_color_no_alpha var opaque_color := Color(0.2, 0.4, 0.6, 1.0)
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var vector_distance := Vector3.ONE


func get_type_id() -> StringName:
	return &"metadata_fixture"


func get_caption() -> String:
	return "Property Metadata Fixture"


func get_category() -> StringName:
	return &"Test"


func get_input_ports() -> Array[ScatterPort]:
	return []


func get_output_ports() -> Array[ScatterPort]:
	return []


func evaluate_value(_context: ScatterEvaluationContext, _inputs: ScatterNodeInputs) -> ScatterValue:
	return null
