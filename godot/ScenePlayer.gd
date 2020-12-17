## Loads and plays a scene's dialogue sequences, delegating to other nodes to display images or text.
class_name ScenePlayer
extends Node

var _dialogue_data = {
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
		next = -1,
	},
}

onready var _text_box := $TextBox
onready var _character_displayer := $CharacterDisplayer


func _ready() -> void:
	run_dialogue_sequence()


func run_dialogue_sequence() -> void:
	var key = _dialogue_data.keys()[0]
	while key != -1:
		var node: Dictionary = _dialogue_data[key]

		# Choice.
		if "choice" in node:
			_text_box.display_choice(node.choice)
			var next_node_key = yield(_text_box, "choice_made")
			key = next_node_key
		# Normal text reply.
		else:
			var character: Character
			if node.has("character"):
				character = CharactersDB.get_character(node.character)

			_text_box.display(node.line, character.display_name)
			_character_displayer.display(node.character)
			yield(_text_box, "next_requested")
			key = node.next

		if node.has("finished"):
			break

	_text_box.hide()
	_character_displayer.hide()
