## Displays and animates [Character] portraits, for example, entering from the left or the right.
## Place it behind a [TextBox].
class_name CharacterDisplayer
extends Node

## Emitted when the characters finished displaying or finished their animation.
signal display_finished

## Maps animation text ids to a function that animates a character sprite.
const ANIMATIONS := {"enter": "_enter", "leave": "_leave", "hidden": "_hidden"}
const SIDE := {LEFT = "left", LEFT_CENTER = "left_center", RIGHT = "right", RIGHT_CENTER = "right_center"}
const COLOR_WHITE_TRANSPARENT = Color(1.0, 1.0, 1.0, 0.0)
const COLOR_SPRITE_NOT_TALKING = Color(0.27451, 0.27451, 0.27451)
const COLOR_SPRITE_FOCUSED = Color(1.0, 1.0, 1.0)

## Keeps track of the character displayed on either side.
var _displayed := {left = null, left_center = null, right = null, right_center = null}
var _focused := ""

onready var _tween: Tween = $Tween
onready var _left_sprite: Sprite = $Left
onready var _right_sprite: Sprite = $Right
onready var _left_center_sprite: Sprite = $LeftCenter
onready var _right_center_sprite: Sprite = $RightCenter


func _ready() -> void:
	_left_sprite.hide()
	_right_sprite.hide()
	_left_center_sprite.hide()
	_right_center_sprite.hide()
	_tween.connect("tween_all_completed", self, "_on_Tween_tween_all_completed")

# NOTE:
# This code does not make sense
# As soon as you press ui_accept the animation is skipped
# That always happens when the player presses Enter/Space to advance the text
# That way animations will never play except for the first animation or when animations play automatically
#
func _unhandled_input(event: InputEvent) -> void:
	# If the player presses enter before the character animations ended, we seek to the end.
#	if event.is_action_pressed("ui_accept") and _tween.is_active():
#		_tween.seek(INF)
	pass


func display(character: Character, side: String = "", expression := "", animation := "") -> void:
#	assert(side in SIDE.values())
	
	# Keeps track of a character that's already displayed on a given side
	var sprite: Sprite = _left_sprite 
	
	if side == SIDE.LEFT:
		sprite = _left_sprite
	elif side == SIDE.LEFT_CENTER:
		sprite = _left_center_sprite
	elif side == SIDE.RIGHT:
		sprite = _right_sprite
	elif side == SIDE.RIGHT_CENTER:
		sprite = _right_center_sprite
	
	if character == _displayed.left:
		sprite = _left_sprite
	elif character == _displayed.right:
		sprite = _right_sprite
	elif character == _displayed.left_center:
		sprite = _left_center_sprite
	elif character == _displayed.right_center:
		sprite = _right_center_sprite
	else:
		_displayed[side] = character
	
	_determine_focus(character.id, side, sprite)
	if _focused == "narrator":
		# Focus none and return.
		focus_sprite()
		return
	
	sprite.texture = character.get_image(expression)
	
	focus_sprite(sprite) # Needs to be done before the animation plays. Don't know why exactly
	
	if animation != "":
		call(ANIMATIONS[animation], side, sprite)
	
	sprite.show()


func _determine_focus(character_id: String, side: String, sprite: Sprite) -> void:
	if character_id == "narrator":
		# We have no other information than the character id to determine the narrator
		_focused = "narrator"
	elif side != "":
		# If there is a side specified, we want to focus that
		_focused = side
	elif side == "":
		# If no side is specified, we need to determine which sprite is talking
		# We need that to cover the following case
		# - Character enters side -> gets focus
		# - Narrator talks -> character looses focus
		# - Character talks again -> no side specified, but the character needs focus
		if sprite == _left_sprite:
			_focused = "left"
		elif sprite == _left_center_sprite:
			_focused = "left_center"
		elif sprite == _right_sprite:
			_focused = "right"
		elif sprite == _right_center_sprite:
			_focused = "right_center"


# Fade all sprites to gray and make the non focused one colored
func focus_sprite(sprite: Sprite = null) -> void:
	
	# We need to make sure not to display a sprite that has left the screen
	if _displayed.left_center != null:
		_left_center_sprite.modulate = COLOR_SPRITE_NOT_TALKING
	if _displayed.left != null:
		_left_sprite.modulate = COLOR_SPRITE_NOT_TALKING
	if _displayed.right_center != null:
		_right_center_sprite.modulate = COLOR_SPRITE_NOT_TALKING
	if _displayed.right != null:
		_right_sprite.modulate = COLOR_SPRITE_NOT_TALKING
	
	if _focused == SIDE.LEFT:
		_left_sprite.modulate = COLOR_SPRITE_FOCUSED
	elif _focused == SIDE.LEFT_CENTER:
		_left_center_sprite.modulate = COLOR_SPRITE_FOCUSED
	elif _focused == SIDE.RIGHT:
		_right_sprite.modulate = COLOR_SPRITE_FOCUSED
	elif _focused == SIDE.RIGHT_CENTER:
		_right_center_sprite.modulate = COLOR_SPRITE_FOCUSED


## Fades in and moves the character to the anchor position.
func _enter(from_side: String, sprite: Sprite) -> void:
	var offset := -200 if (from_side == SIDE.LEFT or from_side == SIDE.LEFT_CENTER) else 200

	var start := sprite.position + Vector2(offset, 0.0)
	var end := sprite.position

	_tween.interpolate_property(
		sprite, "position", start, end, 0.5, Tween.TRANS_QUINT, Tween.EASE_OUT
	)

	_tween.interpolate_property(sprite, "modulate", COLOR_WHITE_TRANSPARENT, Color.white, 0.25)
	_tween.start()

	# Set up the sprite
	# We don't use Tween.seek(0.0) here since that could conflict with running tweens and make them jitter back and forth
	sprite.position = start
	sprite.modulate = COLOR_WHITE_TRANSPARENT

#
# NOTE
# _enter and _leave do not play well together
# _enter takes the original sprite position as a starting point and starts from an offset
# _leave however moves the sprite to an offset and does not reset it to its 
# original position afterwards
# -> This will breake _enter as it takes the offset as its original starting position now
# 
#
func _leave(from_side: String, sprite: Sprite) -> void:
	var offset := -200 if (from_side == SIDE.LEFT or from_side == SIDE.LEFT_CENTER) else 200

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
	
	_tween.connect("tween_all_completed", self, "_on_tween_leave_completed", [from_side, start])
	
	_tween.start()
	_tween.seek(0.0)
#	sprite.modulate = COLOR_WHITE_TRANSPARENT 
	

# Resets the sprite position after a character left
func _on_tween_leave_completed(side: String, original_sprite_position: Vector2) -> void:
	_tween.disconnect("tween_all_completed", self, "_on_tween_leave_completed")
	if side == SIDE.LEFT:
		_left_sprite.position = original_sprite_position
	elif side == SIDE.LEFT_CENTER:
		_left_center_sprite.position = original_sprite_position
	elif side == SIDE.RIGHT:
		_right_sprite.position = original_sprite_position
	elif side == SIDE.RIGHT_CENTER:
		_right_center_sprite.position = original_sprite_position
	
	# We want sprites to be able to leave and reappear somewhere else
	# This is also needed to not show invisible sprites when an other one gets focus
	_displayed[side] = null


# This "animation" is used to allow a character that left the screen to say something
# The sprite is transparent, so it can not show an other character
# This adds not an additional hidden character to the existing 5
func _hidden(from_side: String, sprite: Sprite) -> void:
	sprite.modulate = COLOR_WHITE_TRANSPARENT
	

func _on_Tween_tween_all_completed() -> void:
	emit_signal("display_finished")
