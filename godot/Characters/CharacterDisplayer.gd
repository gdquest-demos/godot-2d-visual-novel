## Displays and animates [Character] portraits, for example, entering from the left or the right.
## Place it behind a [TextBox].
class_name CharacterDisplayer
extends Node

## Maps animation text ids to a function that animates a character sprite.
const ANIMATIONS := {"enter": "_enter", "leave": "_leave"}
const SIDE := {LEFT = "left", RIGHT = "right"}
const COLOR_WHITE_TRANSPARENT = Color(1.0, 1.0, 1.0, 0.0)

## Keeps track of the character displayed on either side.
var _displayed := {left = null, right = null}

onready var _tween: Tween = $Tween
onready var _left_sprite: Sprite = $Left
onready var _right_sprite: Sprite = $Right


func _ready() -> void:
	_left_sprite.hide()
	_right_sprite.hide()


func display(character: Character, side: String = SIDE.LEFT, expression := "", animation := "") -> void:
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
		call(ANIMATIONS[animation], side, sprite)

	sprite.show()


## Fades in and moves the character to the anchor position.
func _enter(from_side: String, sprite: Sprite) -> void:
	var offset := -200 if from_side == SIDE.LEFT else 200

	var start := sprite.position + Vector2(offset, 0.0)
	var end := sprite.position

	_tween.interpolate_property(
		sprite, "position", start, end, 0.5, Tween.TRANS_QUINT, Tween.EASE_OUT
	)
	_tween.interpolate_property(sprite, "modulate", COLOR_WHITE_TRANSPARENT, Color.white, 0.25)
	_tween.start()
	# Using Tween.seek() to set the sprite's position and modulate instantly.
	_tween.seek(0.0)


func _leave(from_side: String, sprite: Sprite) -> void:
	var offset := -200 if from_side == SIDE.LEFT else 200

	var start := sprite.position
	var end := sprite.position + Vector2(offset, 0.0)

	_tween.interpolate_property(
		sprite, "position", start, end, 0.5, Tween.TRANS_QUINT, Tween.EASE_OUT
	)
	_tween.interpolate_property(
		sprite,
		"modulate",
		Color.white,
		COLOR_WHITE_TRANSPARENT,
		0.25,
		Tween.TRANS_LINEAR,
		Tween.EASE_OUT,
		0.25
	)
	_tween.start()
	_tween.seek(0.0)
