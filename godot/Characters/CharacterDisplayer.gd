## Displays and animates [Character] portraits, for example, entering from the left or the right.
## Place it behind a [TextBox].
class_name CharacterDisplayer
extends Node

const SIDE := {
	LEFT = "left",
	RIGHT = "right"
}

## Keeps track of the character displayed on either side.
var _displayed := {
	left = null,
	right = null
}

onready var _tween: Tween = $Tween
onready var _left_sprite: Sprite = $Left
onready var _right_sprite: Sprite = $Right


func _ready() -> void:
	_left_sprite.hide()
	_right_sprite.hide()


func display(character: Character, side :String = SIDE.LEFT, expression := "", animation := "") -> void:
	assert(side in SIDE.values())
	
	# Keeps track of a character that's already displayed on a given side
	var sprite: Sprite = _left_sprite if side == SIDE.LEFT else _right_sprite
	if character == _displayed.left:
		sprite = _left_sprite
	elif character == _displayed.right:
		sprite = _right_sprite
	else:
		_displayed[side] = character

	sprite.texture = character.get_image(expression)

	if animation != "":
		pass

	sprite.show()
