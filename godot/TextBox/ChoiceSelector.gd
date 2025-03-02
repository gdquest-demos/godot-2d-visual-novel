class_name ChoiceSelector
extends VBoxContainer

signal choice_made(target_id)


func display(choices: Array) -> void:
	for choice in choices:
		var button := Button.new()
		button.text = choice.label
		button.pressed.connect(Callable(self, "_on_Button_pressed").bind(choice.target))
		add_child(button)
	(get_child(0) as Button).grab_focus()


func _clear() -> void:
	for child in get_children():
		child.queue_free()


func _on_Button_pressed(target_id: int) -> void:
	choice_made.emit(target_id)
	_clear()
