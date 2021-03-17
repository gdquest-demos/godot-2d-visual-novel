## Loads and plays a scene's dialogue sequences, delegating to other nodes to display images or text.
class_name ScenePlayer
extends Node

signal scene_finished
signal restart_requested
signal transition_finished

const SAVE_FILE_LOCATION := "user://2DVisualNovelDemo.save"

const KEY_END_OF_SCENE := -1
const KEY_RESTART_SCENE := -2

## Maps transition keys to a corresponding function to call.
const TRANSITIONS := {
	fade_in = "_appear_async",
	fade_out = "_disappear_async",
}

var _scene_data := {}

onready var _text_box := $TextBox
onready var _character_displayer := $CharacterDisplayer
onready var _anim_player: AnimationPlayer = $FadeAnimationPlayer
onready var _background := $Background


func run_scene() -> void:
	var key = 0
	while key != KEY_END_OF_SCENE:
		var node: SceneTranspiler.BaseNode = _scene_data[key]
		var character: Character = (
			ResourceDB.get_character(node.character)
			if "character" in node and node.character != ""
			else ResourceDB.get_narrator()
		)

		if node is SceneTranspiler.BackgroundCommandNode:
			var bg: Background = ResourceDB.get_background(node.background)
			_background.texture = bg.texture

		# Displaying a character.
		if "character" in node:
			var side: String = node.side if "side" in node else CharacterDisplayer.SIDE.LEFT
			var animation: String = node.animation
			var expression: String = node.expression
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
			if node.transition != "":
				call(TRANSITIONS[node.transition])
				yield(self, "transition_finished")
			key = node.next

		# Manage variables
		elif node is SceneTranspiler.SetCommandNode:
			add_variable(node.symbol, node.value)
			key = node.next

		# Change to another scene
		elif node is SceneTranspiler.SceneCommandNode:
			if node.scene_path == "next_scene":
				key = KEY_END_OF_SCENE
			else:
				key = node.next

		# Choices.
		elif node is SceneTranspiler.ChoiceTreeNode:
			# Temporary fix for the buttons not showing when there are consecutive choice nodes
			yield(get_tree(), "idle_frame")
			yield(get_tree(), "idle_frame")
			yield(get_tree(), "idle_frame")

			_text_box.display_choice(node.choices)

			key = yield(_text_box, "choice_made")

			if key == KEY_RESTART_SCENE:
				emit_signal("restart_requested")
				return
		elif node is SceneTranspiler.ConditionalTreeNode:
			var variables_list = get_stored_variables_list()

			# Evaluate the if's condition
			if (
				variables_list.has(node.if_block.condition.value)
				and variables_list[node.if_block.condition.value]
			):
				key = node.if_block.next
			else:
				# Have to use this flag because we can't `continue` out of the
				# elif loop
				var elif_condition_fulfilled := false

				# Evaluate the elif's conditions
				for block in node.elif_blocks:
					if (
						variables_list.has(block.condition.value)
						and variables_list[block.condition.value]
					):
						key = block.next
						elif_condition_fulfilled = true
						break

				if not elif_condition_fulfilled:
					if node.else_block:
						# Go to else
						key = node.else_block.next
					else:
						# Move on
						key = node.next

		# Ensures we don't get stuck in an infinite loop if there's no line to display.
		else:
			key = node.next

	_character_displayer.hide()
	emit_signal("scene_finished")


func add_variable(name: String, value) -> void:
	var save_file: File = File.new()

	save_file.open(SAVE_FILE_LOCATION, File.READ_WRITE)

	var data: Dictionary = (
		parse_json(save_file.get_as_text())
		if save_file.get_as_text()
		else {variables = {}}
	)

	if name != "":
		if not data.has("variables"):
			data["variables"] = {}

		data["variables"][name] = evaluate(value)

	save_file.store_line(to_json(data))
	save_file.close()


func get_stored_variables_list() -> Dictionary:
	var save_file: File = File.new()

	# Stop if the save file doesn't exist
	if not save_file.file_exists(SAVE_FILE_LOCATION):
		return {}

	save_file.open(SAVE_FILE_LOCATION, File.READ)

	var data: Dictionary = parse_json(save_file.get_as_text())

	save_file.close()

	return data.variables


func load_scene(dialogue: SceneTranspiler.DialogueTree) -> void:
	# Store the variables at the save file level
	for variable in dialogue.GLOBALS.variables.keys():
		add_variable(variable, dialogue.GLOBALS.variables[variable])

	# The main script
	_scene_data = dialogue.values


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


# Used to evaluate the condition for the conditionals
func evaluate(input):
	var script = GDScript.new()
	script.set_source_code("func eval():\n\treturn " + input)
	script.reload()
	var obj = Reference.new()
	obj.set_script(script)
	return obj.eval()
