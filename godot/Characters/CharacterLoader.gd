class_name CharacterLoader
extends Reference


## Finds and loads [Character] resources in the directory corresponding to `directory_path` and
## returns them as a dictionary with the form {id: Character}, where `id` is a text string.
func load_characters(directory_path: String) -> Dictionary:
	var directory := Directory.new()
	if directory.open(directory_path) != OK:
		return {}

	var characters := {}

	directory.list_dir_begin()
	var filename = directory.get_next()
	while filename != "":
		if filename.ends_with(".tres"):
			var character: Character = load(directory_path.plus_file(filename))
			if not character:
				continue

			characters[character.id] = character
		filename = directory.get_next()
	directory.list_dir_end()

	return characters
