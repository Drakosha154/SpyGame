extends Node3D
class_name ObjectDisplay
## Держатель на пьедестале. Показывает одну из двух моделей загадки по роли.
## Любую модель автоматически подгоняет по размеру и ставит основанием на пьедестал —
## поэтому ассеты из разных паков (в разном масштабе) выглядят одинаково аккуратно.

const TARGET_SIZE := 1.4   # желаемый габарит модели на пьедестале

var _model: Node3D = null


func show_puzzle(puzzle: Puzzle, is_spy: bool) -> void:
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
	if _model is Node3D:
		_fit_to_pedestal(_model)


# Масштабирует модель до TARGET_SIZE и ставит основанием на y=0 держателя.
func _fit_to_pedestal(model: Node3D) -> void:
	var aabb := _model_aabb(model)
	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if max_dim <= 0.0:
		return
	var s := TARGET_SIZE / max_dim
	model.scale = Vector3.ONE * s
	model.position = Vector3(
		-(aabb.position.x + aabb.size.x * 0.5) * s,   # центр по X
		-aabb.position.y * s,                          # низ на пьедестал
		-(aabb.position.z + aabb.size.z * 0.5) * s)    # центр по Z


# Общий размер модели (AABB) в её локальных координатах.
func _model_aabb(model: Node3D) -> AABB:
	var has_any := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	var inv := model.global_transform.affine_inverse()
	for vi in model.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = vi.get_aabb()
		var xf: Transform3D = inv * vi.global_transform
		for i in 8:
			var corner: Vector3 = xf * (a.position + a.size * Vector3(
				float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1)))
			if not has_any:
				min_v = corner
				max_v = corner
				has_any = true
			else:
				min_v = min_v.min(corner)
				max_v = max_v.max(corner)
	if not has_any:
		return AABB()
	return AABB(min_v, max_v - min_v)
