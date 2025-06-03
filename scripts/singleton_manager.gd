extends Node


signal singletons_ready


var TagIt = null
var eSixAPI = null


func reload_singletons() -> void:
	if TagIt != null:
		TagIt.queue_free()
		TagIt = null
	if eSixAPI != null:
		eSixAPI.queue_free()
		eSixAPI = null
	
	TagIt = load("res://scripts/tagit_singleton.gd").new()
	add_child.call_deferred(TagIt)
	
	if not TagIt.is_node_ready():
		await TagIt.ready
	
	eSixAPI = load("res://scripts/e_six_requester.gd").new()
	add_child.call_deferred(eSixAPI)
	
	if not eSixAPI.is_node_ready():
		await eSixAPI.ready
	
	await get_tree().create_timer(0.1).timeout
	
	singletons_ready.emit()
