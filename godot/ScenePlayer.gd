## Loads and plays a scene's dialogue sequences, delegating to other nodes to display images or text.
class_name ScenePlayer
extends Node

signal scene_finished
signal transition_finished

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

# func _ready() -> void:
# 	_text_box.hide()
#	var file := File.new()
#	file.open("res://Scenes/1.scene", File.WRITE)
#	file.store_string(var2str(_scene_data))
#	file.close()


func run_scene() -> void:
	var key = _scene_data.keys()[0]
	while key != -1:
		var node: Dictionary = _scene_data[key]
		
		if "background" in node:
			var bg: Background = ResourceDB.get_background(node.background)
			_background.texture = bg.texture

		# Normal text reply.
		if "line" in node:
			var character: Character
			if "character" in node:
				character = ResourceDB.get_character(node.character)

			var side: String = node["side"] if "side" in node else CharacterDisplayer.SIDE.LEFT

			_text_box.display(node.line, character.display_name)
			_character_displayer.display(character, side)
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
			var next_node_key = yield(_text_box, "choice_made")
			key = next_node_key

		if node.has("finished"):
			break

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
	_text_box.show()
	yield(_text_box.fade_in_async(), "completed")
	emit_signal("transition_finished")


func _disappear_async() -> void:
	yield(_text_box.fade_out_async(), "completed")
	_anim_player.play("fade_out")
	yield(_anim_player, "animation_finished")
	_text_box.hide()
	emit_signal("transition_finished")
