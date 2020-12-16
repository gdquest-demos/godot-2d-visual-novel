## Displays character replies in a dialogue
extends Control

## Emitted when all the text finished displaying.
signal display_finished
## Emitted when the next line was requested
signal next_requested

## Speed at which the characters appear in the text body in characters per second.
export var display_speed := 20.0
export var bbcode_text := "" setget set_bbcode_text

onready var _name_label: Label = $NameLabel
onready var _rich_text_label: RichTextLabel = $RichTextLabel
onready var _tween: Tween = $Tween
onready var _blinking_arrow: Control = $BlinkingArrow


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if _blinking_arrow.visible:
			emit_signal("next_requested")
		else:
			_display_all_content()


func display(text: String, character_name := "", speed := display_speed) -> void:
	set_bbcode_text(text)

	if character_name != "":
		_name_label.text = character_name

	if speed != display_speed:
		display_speed = speed


func set_bbcode_text(text: String) -> void:
	bbcode_text = text
	if not is_inside_tree():
		yield(self, "ready")

	_rich_text_label.bbcode_text = bbcode_text
	# Required for the `_rich_text_label`'s  text to update and the code below to work.
	yield(get_tree(), "idle_frame")
	var character_count := _rich_text_label.get_total_character_count()
	_tween.interpolate_property(
		_rich_text_label, "visible_characters", 0, character_count, character_count / display_speed
	)
	_tween.start()


func _display_all_content() -> void:
	_tween.seek(10000)


func _on_Tween_tween_all_completed() -> void:
	emit_signal("display_finished")
	_blinking_arrow.visible = true
