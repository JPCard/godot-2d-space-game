# A class that represents a dockable object in space that the player can attach
# to. Synchronizes with the docking ship, taking control of it with a remote
# transform, as well as indicating docking range being achieved or lost by
# animating a docking range circle.
class_name DockingPoint
extends Node2D

signal died

export (Resource) var map_icon = MapIcon.new()
export var docking_distance := 200.0 setget _set_docking_distance

var angle_proportion := 1.0
var is_player_inside := false
var radius := 0.0
var docking_point_edge := Vector2.ZERO


onready var docking_shape: CollisionShape2D = $DockingArea/CollisionShape2D
onready var docking_area: Area2D = $DockingArea
onready var collision_shape: CollisionShape2D = $KinematicBody2D/CollisionShape2D
onready var agent_location := GSAISteeringAgent.new()
onready var remote_rig: Node2D = $RemoteRig
onready var remote_transform: RemoteTransform2D = $RemoteRig/RemoteTransform2D
onready var ref_to := weakref(self)
onready var tween := $Tween
onready var dock_aura := $Sprite/ActiveAura
onready var animator := $AnimationPlayer


func _ready() -> void:
	radius = collision_shape.shape.radius
	agent_location.position.x = global_position.x
	agent_location.position.y = global_position.y
	agent_location.orientation = rotation
	agent_location.bounding_radius = radius
	docking_point_edge = Vector2.UP * radius

	docking_area.connect("body_entered", self, "_on_DockingArea_body_entered")
	docking_area.connect("body_exited", self, "_on_DockingArea_body_exited")


func set_docking_remote(node: Node2D, docker_distance: float) -> void:
	remote_rig.global_rotation = GSAIUtils.vector2_to_angle(node.global_position - global_position)
	remote_transform.position = docking_point_edge + Vector2.UP * (docker_distance / scale.x)
	remote_transform.remote_path = node.get_path()


func undock() -> void:
	remote_transform.remote_path = ""


func register_on_map(map: Viewport) -> void:
	var id: int = map.register_map_object($MapTransform, map_icon)
	# warning-ignore:return_value_discarded
	connect("died", map, "remove_map_object", [id])


func _set_docking_distance(value: float) -> void:
	docking_distance = value
	if not is_inside_tree():
		yield(self, "ready")

	docking_shape.shape.radius = value


func _on_DockingArea_body_entered(body: Node) -> void:
	is_player_inside = true
	body.dockables.append(ref_to)
	animator.stop(false)
	tween.interpolate_property(
		dock_aura,
		"scale", 
		Vector2(0.01, 0.01),
		Vector2(2.15, 2.15),
		1.0,
		Tween.TRANS_ELASTIC,
		Tween.EASE_OUT)
	dock_aura.visible = true
	tween.start()


func _on_DockingArea_body_exited(body: Node) -> void:
	is_player_inside = false
	var index: int = body.dockables.find(ref_to)
	if index > -1:
		body.dockables.remove(index)
	animator.play()
	tween.interpolate_property(
		dock_aura,
		"scale", 
		Vector2(2.15, 2.15),
		Vector2(0.01, 0.01),
		0.5,
		Tween.TRANS_BACK,
		Tween.EASE_IN)
	tween.start()
	yield(tween, "tween_all_completed")
	dock_aura.visible = false

