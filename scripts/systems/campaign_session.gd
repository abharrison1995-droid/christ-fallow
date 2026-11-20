extends Node
## Owns the mounted campaign underneath the title scene.

signal title_restored

const Campaign := preload("res://scenes/main.tscn")

var _campaign: Node
var _returning := false


func _ready() -> void:
	GameState.title_requested.connect(return_to_title)


func launch(load_saved: bool, leader: String, tribe: String, lineage: int) -> bool:
	if is_instance_valid(_campaign) or _returning:
		return false
	_campaign = Campaign.instantiate()
	add_child(_campaign)
	var launched := GameState.load_game() if load_saved else GameState.start_new_campaign(leader, tribe, lineage)
	if not launched:
		_dispose()
	return launched


func return_to_title() -> void:
	if _returning or not is_instance_valid(_campaign):
		return
	_returning = true
	_finish_return.call_deferred()


func _finish_return() -> void:
	_dispose()
	_returning = false
	title_restored.emit()


func _dispose() -> void:
	remove_child(_campaign)
	_campaign.queue_free()
	_campaign = null
	GameState.end_campaign()


func _exit_tree() -> void:
	if is_instance_valid(_campaign):
		GameState.end_campaign()
