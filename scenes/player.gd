extends CharacterBody3D
## Игрок от первого лица + сеть. Двигается только владелец (authority);
## остальные видят его тело через MultiplayerSynchronizer.

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003

@onready var camera: Camera3D = $Camera3D
@onready var body: MeshInstance3D = $Body

var min_pitch: float = deg_to_rad(-89.0)
var max_pitch: float = deg_to_rad(89.0)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	# Владелец узла = игрок с таким peer_id. Имя узла = его id (ставим при спавне).
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	var mine := is_multiplayer_authority()
	camera.current = mine        # своя камера активна
	body.visible = not mine      # своё тело прячем, чужие показываем
	if mine:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_go_to_spawn("LobbyRoom")     # старт в лобби-комнате (владелец ставит себя сам)


# Поставить себя на точку спавна нужной комнаты (арена у всех одинаковая).
func _go_to_spawn(room_name: String) -> void:
	# Путь от тела: Players -> Arena -> <комната>/Spawn
	var spawn := get_node_or_null("../../" + room_name + "/Spawn") as Node3D
	if spawn == null:
		return
	# Небольшой сдвиг по id, чтобы игроки не спавнились друг в друге.
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


func _physics_process(delta: float) -> void:
	# Чужими телами не управляем — их позицию задаёт синхронизатор.
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
