extends Node3D
class_name ObjectDisplay
## Держатель на пьедестале. Показывает ОДНУ из двух моделей загадки
## в зависимости от роли игрока. Чужую модель клиент не создаёт (важно для сети).

var _model: Node3D = null


# Показать загадку. is_spy = true → модель шпиона, иначе модель экипажа.
func show_puzzle(puzzle: Puzzle, is_spy: bool) -> void:
	# Убираем прошлую модель, если была.
	if _model != null:
		_model.queue_free()
		_model = null

	if puzzle == null:
		return

	var scene: PackedScene = puzzle.spy_scene if is_spy else puzzle.crew_scene
	if scene == null:
		push_warning("ObjectDisplay: у загадки '%s' не задана модель" % puzzle.display_name)
		return

	_model = scene.instantiate()
	add_child(_model)
