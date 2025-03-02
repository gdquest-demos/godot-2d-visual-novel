## Data container for characters
class_name Character
extends Resource

@export var id := "character_id"
@export var display_name := "Display Name"
@export var bio := "Fill this with the character's complete bio. Supports BBCode." # (String, MULTILINE)
@export var age := 0: set = set_age

## Default key to use if the user doesn't specify the image to display
@export var default_image := "neutral"
## Holds the character's portraits, mapping expressions (keys) to an image texture.
@export var images := {
	neutral = null,
}


func _init() -> void:
	assert(default_image in images)


func get_default_image() -> Texture2D:
	return images[default_image]


func get_image(expression: String) -> Texture2D:
	return images.get(expression, get_default_image())


func set_age(value: int) -> void:
	age = int(min(value, 0))
