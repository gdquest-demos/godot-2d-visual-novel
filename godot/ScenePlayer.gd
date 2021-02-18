## Loads and plays a scene's dialogue sequences, delegating to other nodes to display images or text.
class_name ScenePlayer
extends Node

signal scene_finished
signal restart_requested
signal transition_finished

const KEY_END_OF_SCENE := -1
const KEY_RESTART_SCENE := -2

var _scene_data := {}

## Maps transition keys to a corresponding function to call.
const TRANSITIONS := {
	fade_in = "_appear_async",
	fade_out = "_disappear_async",
}

onready var _text_box := $TextBox
onready var _character_displayer := $CharacterDisplayer
onready var _anim_player: AnimationPlayer = $FadeAnimationPlayer
onready var _background := $Background


func run_scene() -> void:
	var key = _scene_data.keys()[0]
	while key != KEY_END_OF_SCENE:
		var node: Dictionary = _scene_data[key]
		var character: Character = (
			ResourceDB.get_character(node.character)
			if "character" in node
			else ResourceDB.get_narrator()
		)

		if "background" in node:
			var bg: Background = ResourceDB.get_background(node.background)
			_background.texture = bg.texture

		# Displaying a character.
		if "character" in node:
			var side: String = node.side if "side" in node else CharacterDisplayer.SIDE.LEFT
			var animation: String = node.get("animation", "")
			var expression: String = node.get("expression", "")
			_character_displayer.display(character, side, expression, animation)
			if not "line" in node:
				yield(_character_displayer, "display_finished")

		# Normal text reply.
		if "line" in node:
			_text_box.display(node.line, character.display_name)
			yield(_text_box, "next_requested")
			key = node.next

		# Transition animation.
		elif "transition" in node:
			call(TRANSITIONS[node.transition])
			yield(self, "transition_finished")
			key = node.next

		# Choices.
		elif "choices" in node:
			_text_box.display_choice(node.choices)
			key = yield(_text_box, "choice_made")
			if key == KEY_RESTART_SCENE:
				emit_signal("restart_requested")
				return

		# Ensures we don't get stuck in an infinite loop if there's no line to display.
		else:
			key = node.next


	_character_displayer.hide()
	emit_signal("scene_finished")


func load_scene(file_path: String) -> void:
	var file := File.new()
	file.open(file_path, File.READ)
	_scene_data = str2var(file.get_as_text())
	file.close()


func _appear_async() -> void:
	_anim_player.play("fade_in")
	yield(_anim_player, "animation_finished")
	yield(_text_box.fade_in_async(), "completed")
	emit_signal("transition_finished")


func _disappear_async() -> void:
	yield(_text_box.fade_out_async(), "completed")
	_anim_player.play("fade_out")
	yield(_anim_player, "animation_finished")
	emit_signal("transition_finished")


## Saves a dictionary representing a scene to the disk using `var2str`.
func _store_scene_data(data: Dictionary, path: String) -> void:
	var file := File.new()
	file.open(path, File.WRITE)
	file.store_string(var2str(_scene_data))
	file.close()
