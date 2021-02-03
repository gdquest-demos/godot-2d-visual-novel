extends TextureRect

const COLOR_WHITE_TRANSPARENT := Color(1.0, 1.0, 1.0, 0.0)

onready var _tween: Tween = $Tween


func _ready() -> void:
	modulate = COLOR_WHITE_TRANSPARENT


func appear() -> void:
	_tween.interpolate_property(self, "modulate", COLOR_WHITE_TRANSPARENT, Color.white, 0.4)
	_tween.start()
	_tween.seek(0)


func disappear() -> void:
	_tween.interpolate_property(self, "modulate", Color.white, COLOR_WHITE_TRANSPARENT, 0.2)
	_tween.start()
	_tween.seek(0)
