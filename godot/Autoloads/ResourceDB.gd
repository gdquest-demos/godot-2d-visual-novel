## Auto-loaded node that loads and gives access to all [Background] resources in the game.
extends Node

const NARRATOR_ID := "narrator"

onready var _characters := _load_resources("res://Characters/", "_is_character")
onready var _backgrounds := _load_resources("res://Backgrounds/", "_is_background")


func get_character(character_id: String) -> Character:
	return _characters.get(character_id)


func get_narrator() -> Character:
	return _characters.get(NARRATOR_ID)


func get_background(background_id: String) -> Background:
	return _backgrounds.get(background_id)


## Finds and loads resources of a given type in `directory_path`.
## As we don't have generics in GDScript, we pass a function's name to do type checks.
## We call that function on each loaded resource with `call()`.
func _load_resources(directory_path: String, check_type_function: String) -> Dictionary:
	var directory := Directory.new()
	if directory.open(directory_path) != OK:
		return {}

	var resources := {}

	directory.list_dir_begin()
	var filename = directory.get_next()
	while filename != "":
		if filename.ends_with(".tres"):
			var resource: Resource = load(directory_path.plus_file(filename))

			if not call(check_type_function, resource):
				continue

			resources[resource.id] = resource
		filename = directory.get_next()
	directory.list_dir_end()

	return resources


func _is_character(resource: Resource) -> bool:
	return resource is Character


func _is_background(resource: Resource) -> bool:
	return resource is Background
