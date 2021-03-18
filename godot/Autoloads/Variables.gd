## Auto-loaded node that handles global variables
extends Node

const SAVE_FILE_LOCATION := "user://2DVisualNovelDemo.save"


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

		data["variables"][name] = _evaluate(value)

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


# Used to evaluate the variables' values
func _evaluate(input):
	var script = GDScript.new()
	script.set_source_code("func eval():\n\treturn " + input)
	script.reload()
	var obj = Reference.new()
	obj.set_script(script)
	return obj.eval()
