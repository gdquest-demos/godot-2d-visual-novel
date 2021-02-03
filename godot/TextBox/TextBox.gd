## Displays character replies in a dialogue
extends Control

## Emitted when all the text finished displaying.
signal display_finished
## Emitted when the next line was requested
signal next_requested
signal choice_made(target_id)

const ChoiceSelector := preload("res://ChoiceSelector.tscn")

## Speed at which the characters appear in the text body in characters per second.
export var display_speed := 20.0
export var bbcode_text := "" setget set_bbcode_text

onready var _name_label: Label = $NameBackground/NameLabel
onready var _rich_text_label: RichTextLabel = $RichTextLabel
onready var _tween: Tween = $Tween
onready var _blinking_arrow: Control = $BlinkingArrow
onready var _anim_player: AnimationPlayer = $FadeAnimationPlayer


func _ready() -> void:
	visible = false
	_name_label.text = ""
	_rich_text_label.bbcode_text = ""
	_rich_text_label.visible_characters = 0
	_tween.connect("tween_all_completed", self, "_on_Tween_tween_all_completed")


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


func display_choice(choices: Array) -> void:
	_name_label.hide()
	_rich_text_label.hide()
	_blinking_arrow.hide()

	var choice_selector: ChoiceSelector = ChoiceSelector.instance()
	add_child(choice_selector)
	choice_selector.setup(choices)
	choice_selector.connect("choice_made", self, "_on_ChoiceSelector_choice_made")


func set_bbcode_text(text: String) -> void:
	bbcode_text = text
	if not is_inside_tree():
		yield(self, "ready")

	_blinking_arrow.hide()
	_rich_text_label.bbcode_text = bbcode_text
	# Required for the `_rich_text_label`'s  text to update and the code below to work.
	call_deferred("_begin_dialogue_display")


func _begin_dialogue_display() -> void:
	var character_count := _rich_text_label.get_total_character_count()
	_tween.interpolate_property(
		_rich_text_label, "visible_characters", 0, character_count, character_count / display_speed
	)
	_tween.start()


func _display_all_content() -> void:
	_tween.seek(10000)


func fade_in_async() -> void:
	_anim_player.play("fade_in")
	_anim_player.seek(0.0, true)
	yield(_anim_player, "animation_finished")


func fade_out_async() -> void:
	_anim_player.play("fade_out")
	yield(_anim_player, "animation_finished")


func _on_Tween_tween_all_completed() -> void:
	emit_signal("display_finished")
	_blinking_arrow.visible = true


func _on_ChoiceSelector_choice_made(target_id: int) -> void:
	emit_signal("choice_made", target_id)
	_name_label.show()
	_rich_text_label.show()
