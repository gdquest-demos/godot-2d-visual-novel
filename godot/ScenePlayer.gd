## Loads and plays a scene's dialogue sequences, delegating to other nodes to display images or text.
class_name ScenePlayer
extends Node

signal transition_finished

var _scene_data = {
	0:
	{
		transition = "fade_in",
		next = 1,
	},
	1:
	{
		character = "bear",
		line = "Hi there! My name's Bear. How about you?",
		next = 2,
	},
	2:
	{
		character = "cat",
		line = "Hey, I'm Cat.",
		next = 3,
	},
	3:
	{
		choice = [
			Choice.new("Start over", 1), Choice.new("Continue", 4), Choice.new("Jump ahead", 5)
		]
	},
	4:
	{
		character = "bear",
		line = "Well, let's continue.",
		next = 5,
	},
	5:
	{
		character = "cat",
		line = "Did you jump ahead?",
		next = 6,
	},
	6:
	{
		next = -1,
		transition = "fade_out",
	}
}

## Maps transition keys to a corresponding function to call.
const TRANSITIONS := {
	fade_in = "_appear_async",
	fade_out = "_disappear_async",
}

onready var _text_box := $TextBox
onready var _character_displayer := $CharacterDisplayer
onready var _anim_player: AnimationPlayer = $FadeAnimationPlayer


func _ready() -> void:
	_text_box.hide()
	yield(run_scene_async(), "completed")


func run_scene_async() -> void:
	var key = _scene_data.keys()[0]
	while key != -1:
		var node: Dictionary = _scene_data[key]

		# Normal text reply.
		if "line" in node:
			var character: Character
			if node.has("character"):
				character = CharactersDB.get_character(node.character)

			_text_box.display(node.line, character.display_name)
			_character_displayer.display(node.character)
			yield(_text_box, "next_requested")
			key = node.next

		# Transition animation.
		elif "transition" in node:
			call(TRANSITIONS[node.transition])
			yield(self, "transition_finished")
			key = node.next

		# Choice.
		elif "choice" in node:
			_text_box.display_choice(node.choice)
			var next_node_key = yield(_text_box, "choice_made")
			key = next_node_key

		if node.has("finished"):
			break

	_character_displayer.hide()


func load_scene(file_path: String) -> Dictionary:
	var file := File.new()
	file.open(file_path, File.READ)
	var data: Dictionary = str2var(file.get_as_text())
	file.close()
	return data


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
