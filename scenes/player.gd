extends CharacterBody3D
## Игрок от первого лица + сеть.
## В фазе голосования: наводишь камеру на игрока и жмёшь ЛКМ — голос за него.

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

@onready var camera: Camera3D = $Camera3D
@onready var body: MeshInstance3D = $Body
@onready var vote_ray: RayCast3D = $Camera3D/RayCast3D
@onready var vote_label: Label3D = $VoteCount

var min_pitch: float = deg_to_rad(-89.0)
var max_pitch: float = deg_to_rad(89.0)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	add_to_group("players")
	vote_label.visible = false
	var mine := is_multiplayer_authority()
	camera.current = mine
	body.visible = not mine
	if mine:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		vote_ray.add_exception(self)   # луч не цепляет собственное тело
		_go_to_spawn("LobbyRoom")


func _go_to_spawn(room_name: String) -> void:
	var spawn := get_node_or_null("../../" + room_name + "/Spawn") as Node3D
	if spawn == null:
		return
	var offset := float(str(name).to_int() % 5) * 1.2 - 2.4
	global_position = spawn.global_position + Vector3(offset, 0, 0)


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


# На кого сейчас направлен луч (id игрока) или -1.
func get_aim_target_id() -> int:
	if vote_ray != null and vote_ray.is_colliding():
		var c = vote_ray.get_collider()
		if c != null and c.is_in_group("players") and c != self:
			return str(c.name).to_int()
	return -1


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
