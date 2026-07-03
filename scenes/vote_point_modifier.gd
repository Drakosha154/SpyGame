extends SkeletonModifier3D
## Свой модификатор скелета вместо LookAtModifier3D: тот сам решал "вторичное
## вращение" (крутку руки), и это давало непредсказуемый твист (рука уходила
## за голову). Здесь — только поворот "по кратчайшей дуге" на нужную ось,
## без дополнительной крутки, плюс распрямление предплечья/кисти и подгибание
## пальцев в кулак (кроме указательного).

const POINT_GESTURE_DURATION := 1.2

const UPPER_ARM_BONE := "B-upperArm.R"
const FOREARM_BONE := "B-forearm.R"
const HAND_BONE := "B-hand.R"

const CURL_FINGER_BONES := [
	"B-thumb01.R", "B-thumb02.R", "B-thumb03.R",
	"B-middleFinger01.R", "B-middleFinger02.R", "B-middleFinger03.R",
	"B-ringFinger01.R", "B-ringFinger02.R", "B-ringFinger03.R",
	"B-pinky01.R", "B-pinky02.R", "B-pinky03.R",
]

var player: Node3D  # ждём vote_target_id и global_transform у CharacterBody3D игрока
var is_pointing: bool = false  # читает player.gd, чтобы показать своё тело в этот момент

var _upper_arm_idx := -1
var _forearm_idx := -1
var _hand_idx := -1
var _parent_idx := -1
var _local_axis := Vector3.FORWARD
var _curl_indices: Array[int] = []
var _last_vote_target_id := -1
var _point_time_left := 0.0


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_upper_arm_idx = skeleton.find_bone(UPPER_ARM_BONE)
	_forearm_idx = skeleton.find_bone(FOREARM_BONE)
	_hand_idx = skeleton.find_bone(HAND_BONE)
	if _upper_arm_idx != -1:
		_parent_idx = skeleton.get_bone_parent(_upper_arm_idx)
		if _forearm_idx != -1:
			var dir := skeleton.get_bone_rest(_forearm_idx).origin
			if dir.length() > 0.001:
				_local_axis = dir.normalized()
	for bone_name in CURL_FINGER_BONES:
		var idx := skeleton.find_bone(bone_name)
		if idx != -1:
			_curl_indices.append(idx)


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or player == null or _upper_arm_idx == -1:
		is_pointing = false
		return

	var vote_target_id: int = player.vote_target_id
	if vote_target_id != -1 and vote_target_id != _last_vote_target_id:
		_point_time_left = POINT_GESTURE_DURATION
	_last_vote_target_id = vote_target_id
	_point_time_left = maxf(_point_time_left - delta, 0.0)
	is_pointing = _point_time_left > 0.0
	if not is_pointing:
		return

	# Целимся строго вперёд по направлению взгляда персонажа (см. player.gd) —
	# в момент голосования цель и так примерно по курсору.
	var forward: Vector3 = -player.global_transform.basis.z
	var target_world: Vector3 = player.global_position + forward * 3.0 + Vector3(0, 1.3, 0)

	var bone_global_pose := skeleton.get_bone_global_pose(_upper_arm_idx)
	var bone_world_pos: Vector3 = skeleton.global_transform * bone_global_pose.origin
	var dir_world := (target_world - bone_world_pos).normalized()
	var dir_skel_local: Vector3 = skeleton.global_transform.basis.inverse() * dir_world

	var parent_basis := Basis.IDENTITY
	if _parent_idx != -1:
		parent_basis = skeleton.get_bone_global_pose(_parent_idx).basis
	var dir_parent_local: Vector3 = (parent_basis.inverse() * dir_skel_local).normalized()

	# Поворот "по кратчайшей дуге" — без лишней крутки вокруг оси прицеливания.
	var new_rot := Quaternion(_local_axis, dir_parent_local)
	skeleton.set_bone_pose_rotation(_upper_arm_idx, new_rot)

	# Предплечье и кисть возвращаем к их РЕСТ-повороту (а не Quaternion.IDENTITY —
	# "нулевой" поворот в локальных осях кости не значит "прямо", если рест-поза
	# сама по себе не выровнена по осям; из-за этого руку и выворачивало) —
	# так убираем унаследованный от idle-анимации сгиб локтя, но не ломаем сустав.
	if _forearm_idx != -1:
		skeleton.set_bone_pose_rotation(_forearm_idx, skeleton.get_bone_rest(_forearm_idx).basis.get_rotation_quaternion())
	if _hand_idx != -1:
		skeleton.set_bone_pose_rotation(_hand_idx, skeleton.get_bone_rest(_hand_idx).basis.get_rotation_quaternion())

	var curl := Quaternion(Vector3.RIGHT, deg_to_rad(70.0))
	for idx in _curl_indices:
		var rest_rot := skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(idx, rest_rot * curl)
