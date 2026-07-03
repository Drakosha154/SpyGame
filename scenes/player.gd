extends CharacterBody3D
## Игрок от первого лица + сеть.
## В фазе голосования: наводишь камеру на игрока и жмёшь ЛКМ — голос за него.

const IDLE_ANIM_SCENE := preload("res://assets/models/human/anims/HumanM_Idle01.fbx")
const WALK_ANIM_SCENE := preload("res://assets/models/human/anims/HumanM_Walk01_Forward.fbx")
const BODY_SKIN := preload("res://assets/models/human/HumanAnimations_ColorPalette.png")
const VotePointModifierScript := preload("res://scenes/vote_point_modifier.gd")

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

@onready var camera: Camera3D = $Camera3D
@onready var body: Node3D = $Body
@onready var anim_player: AnimationPlayer = $Body/AnimationPlayer
@onready var vote_ray: RayCast3D = $Camera3D/RayCast3D
@onready var vote_label: Label3D = $VoteCount
@onready var name_label: Label3D = $NameLabel

var min_pitch: float = deg_to_rad(-89.0)
var max_pitch: float = deg_to_rad(89.0)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# За кого сейчас голосует этот игрок (-1 = ни за кого) — реплицируется (см. RC_1),
# чтобы рука-указатель была видна и на удалённых копиях игрока.
# Читает vote_point_modifier.gd, повешенный на скелет тела.
var vote_target_id: int = -1
var _is_mine: bool = false
var _point_modifier: SkeletonModifier3D


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	add_to_group("players")
	_apply_body_skin()
	_build_animations()
	_setup_point_gesture()
	GameState.phase_changed.connect(_on_phase_changed)
	vote_label.visible = false
	_is_mine = is_multiplayer_authority()
	camera.current = _is_mine
	body.visible = not _is_mine
	name_label.visible = not _is_mine
	_update_name_label()
	NetworkManager.player_list_changed.connect(_update_name_label)
	if _is_mine:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		vote_ray.add_exception(self)   # луч не цепляет собственное тело
		_go_to_spawn("LobbyRoom")


func _go_to_spawn(room_name: String) -> void:
	var spawn := get_node_or_null("../../" + room_name + "/Spawn") as Node3D
	if spawn == null:
		return
	var offset := float(str(name).to_int() % 5) * 1.2 - 2.4
	global_position = spawn.global_position + Vector3(offset, 0, 0)


# --- Анимация тела (idle/walk по реальной скорости) ---
# velocity реплицируется по сети (см. RC_1), поэтому у чужих игроков она
# тоже валидна, а не только у локального — иначе аниматор дёргается между
# редкими обновлениями позиции и персонаж выглядит "скользящим".
func _process(delta: float) -> void:
	if anim_player == null:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target := "walk" if horizontal_speed > 0.3 else "idle"
	if anim_player.current_animation != target:
		anim_player.play(target, 0.2)

	# В первом лице своё тело обычно скрыто (see body.visible ниже), иначе
	# указывающую руку не видно у самого себя — показываем тело на время жеста.
	if _is_mine and _point_modifier != null:
		body.visible = _point_modifier.is_pointing


# Жест "указывает пальцем вперёд" при голосовании реализован отдельным
# SkeletonModifier3D (vote_point_modifier.gd), навешенным на скелет тела —
# он читает vote_target_id и сам решает, когда и как показывать руку.
func _setup_point_gesture() -> void:
	var skeleton := _find_skeleton(body)
	if skeleton == null:
		push_warning("Player: не найден Skeleton3D — жест голосования недоступен.")
		return
	_point_modifier = VotePointModifierScript.new()
	_point_modifier.player = self
	skeleton.add_child(_point_modifier)


# Сбрасываем при любой смене фазы: сервер тоже чистит голоса в начале
# каждого раунда голосования (включая переголосование при ничьей).
func _on_phase_changed(_level: int, _phase: int, _seconds: float) -> void:
	if is_multiplayer_authority():
		vote_target_id = -1


# FBX-модель приходит без привязанной текстуры — назначаем палитру кожи сами.
func _apply_body_skin() -> void:
	var mesh_instance := body.find_child("HumanM_BodyMesh", true, false) as MeshInstance3D
	if mesh_instance == null:
		push_warning("Player: не найден меш HumanM_BodyMesh для наложения текстуры.")
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = BODY_SKIN
	mesh_instance.set_surface_override_material(0, mat)


func _build_animations() -> void:
	if anim_player == null:
		return
	var dst_skeleton := _find_skeleton(body)
	if dst_skeleton == null:
		push_warning("Player: не найден Skeleton3D в теле игрока — анимации не подключены.")
		return
	var dst_skel_path := anim_player.get_path_to(dst_skeleton)
	_add_animation_from_scene(IDLE_ANIM_SCENE, "idle", dst_skel_path)
	_add_animation_from_scene(WALK_ANIM_SCENE, "walk", dst_skel_path)


# Клипы анимации импортированы как отдельные FBX (свой Skeleton3D + AnimationPlayer
# без меша). Кости совпадают по именам с моделью, но путь до скелета внутри сцены
# клипа может отличаться от пути внутри Player.tscn — поэтому переписываем узел
# в путях дорожек на актуальный dst_skel_path, оставляя имя кости как есть.
func _add_animation_from_scene(scene: PackedScene, anim_name: String, dst_skel_path: NodePath) -> void:
	var temp := scene.instantiate()
	var src_player := _find_anim_player(temp)
	var src_skeleton := _find_skeleton(temp)
	if src_player == null or src_skeleton == null:
		push_warning("Player: не найден AnimationPlayer/Skeleton3D в %s" % scene.resource_path)
		temp.queue_free()
		return
	var src_skel_path := str(src_player.get_path_to(src_skeleton))

	var lib := anim_player.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)

	for clip_name in src_player.get_animation_list():
		var anim: Animation = src_player.get_animation(clip_name)
		for i in anim.get_track_count():
			var path_str := str(anim.track_get_path(i))
			var colon := path_str.find(":")
			var node_part := path_str if colon == -1 else path_str.substr(0, colon)
			if node_part == src_skel_path:
				var suffix := "" if colon == -1 else path_str.substr(colon)
				anim.track_set_path(i, NodePath(str(dst_skel_path) + suffix))
		lib.add_animation(anim_name, anim)
	temp.queue_free()


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for child in n.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for child in n.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, min_pitch, max_pitch)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Голосование: ЛКМ по тому, на кого смотришь.
	if event.is_action_pressed("vote_select") and GameState.current_phase == GameState.Phase.VOTING:
		var tid := get_aim_target_id()
		if tid != -1:
			GameState.cast_vote(tid)
			vote_target_id = tid


# На кого сейчас направлен луч (id игрока) или -1.
func get_aim_target_id() -> int:
	if vote_ray != null and vote_ray.is_colliding():
		var c = vote_ray.get_collider()
		if c != null and c.is_in_group("players") and c != self:
			return str(c.name).to_int()
	return -1


# --- Ник над головой ---

func _update_name_label() -> void:
	var id := get_multiplayer_authority()
	name_label.text = str(NetworkManager.players.get(id, "?"))


# --- Метка с числом голосов над головой ---

func show_vote_label() -> void:
	vote_label.visible = true

func hide_vote_label() -> void:
	vote_label.visible = false

func set_vote_count(n: int) -> void:
	vote_label.text = str(n)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
