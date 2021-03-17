extends Node


export (Array, String, FILE) var scripts

const ScenePlayer := preload("res://ScenePlayer.tscn")

const SCENES := []

var _current_index := -1
var _scene_player: ScenePlayer


var lexer := SceneLexer.new()
var parser := SceneParser.new()
var transpiler := SceneTranspiler.new()


func _ready() -> void:

	if not scripts.empty():
		for script in scripts:
			var text := lexer.read_file_content(script)
			var tokens: Array = lexer.tokenize(text)

			var tree: SceneParser.SyntaxTree = parser.parse(tokens)

			var dialogue: SceneTranspiler.DialogueTree = transpiler.transpile(tree, 0)

			# Make sure the scene is transitioned properly at the end of the script
			if not dialogue.nodes[dialogue.index - 1] is SceneTranspiler.JumpCommandNode:
				(dialogue.nodes[dialogue.index - 1] as SceneTranspiler.BaseNode).next = -1

			SCENES.append(dialogue)

		_play_scene(0)


func _play_scene(index: int) -> void:
	_current_index = int(clamp(index, 0.0, SCENES.size() - 1))

	if _scene_player:
		_scene_player.queue_free()

	_scene_player = ScenePlayer.instance()
	add_child(_scene_player)
	_scene_player.load_scene(SCENES[_current_index])
	_scene_player.connect("scene_finished", self, "_on_ScenePlayer_scene_finished")
	_scene_player.connect("restart_requested", self, "_on_ScenePlayer_restart_requested")
	_scene_player.run_scene()


func _on_ScenePlayer_scene_finished() -> void:
	# If the scene that ended is the last scene, we're done playing the game.
	if _current_index == SCENES.size() - 1:
		return
	_play_scene(_current_index + 1)


func _on_ScenePlayer_restart_requested() -> void:
	_play_scene(_current_index)
