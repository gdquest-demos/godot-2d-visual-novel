extends Node

const ScenePlayer := preload("res://ScenePlayer.tscn")

const SCENES := [
	"res://Scenes/1.scene"
]

func _ready() -> void:
	for scene in SCENES:
		var scene_player = ScenePlayer.instance()
		add_child(scene_player)
		scene_player.load_scene(scene)
		scene_player.run_scene()
		yield(scene_player, "scene_finished")
		scene_player.queue_free()
		
