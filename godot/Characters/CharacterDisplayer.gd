## Displays and animates [Character] portraits, for example, entering from the left or the right.
## Place it behind a [TextBox].
class_name CharacterDisplayer
extends Node

enum Side { LEFT, RIGHT }

onready var _tween: Tween = $Tween
onready var _left_sprite: Sprite = $Left
onready var _right_sprite: Sprite = $Right


func _ready() -> void:
	_left_sprite.hide()
	_right_sprite.hide()


func display(character_id: String, side := Side.LEFT, expression := "", animation := "") -> void:
	var sprite: Sprite = _left_sprite if side == Side.LEFT else _right_sprite
	var character: Character = ResourceDB.get_character(character_id)

	sprite.texture = character.get_image(expression)

	if animation != "":
		pass

	sprite.show()
