extends Control


const CURRENT_MAJOR: int = 3
const CURRENT_MINOR: int = 0
const CURRENT_PATCH: int = 0

var new_major: int = CURRENT_MAJOR
var new_minor: int = CURRENT_MINOR
var new_patch: int = CURRENT_PATCH

var download_url: String = ""

@onready var update_requester: HTTPRequest = $UpdateRequester
@onready var update_btn: Button = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/ButtonContainer/UpdateBtn
@onready var skip_btn: Button = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/ButtonContainer/SkipBtn
@onready var ignore_btn: Button = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/ButtonContainer/IgnoreBtn
@onready var status_label: Label = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/StatusLabel
@onready var update_available_lbl: Label = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/UpdateAvailableLbl
@onready var margin_container: MarginContainer = $MainPanel/MainContainer/DataContainer/MarginContainer
@onready var splash: TextureRect = $Splash
@onready var main_panel: PanelContainer = $MainPanel


func _ready() -> void:
	margin_container.visible = false
	splash.visible = false
	
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--no-update") and FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/tagit.pck"):
		load_tagger()
		return
	
	var version_file = FileAccess.open(OS.get_executable_path().get_basename() + "/version", FileAccess.READ)
	var version_text: String = version_file.get_as_text().strip_edges().to_lower() if version_file != null else ""
	
	if not version_text.is_empty():
		if version_text == "x":
			load_tagger()
			return
		else:
			var split_string: PackedStringArray = version_text.split(".", false)
			if split_string.size() == 3:
				var version_idx: int = -1
				var version_array: Array[int] = [CURRENT_MAJOR, CURRENT_MINOR, CURRENT_PATCH]
				for item in split_string:
					version_idx += 1
					if 2 < version_idx:
						break
					if item.is_valid_int():
						version_array[version_idx] = int(item)
				
				if version_array[0] == CURRENT_MAJOR and version_array[1] == CURRENT_MINOR and version_array[2] == CURRENT_PATCH and FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/tagit.pck"):
					load_tagger()
					return
	
	var online_version: Array[int] = await get_online_version()
	
	if download_url.is_empty():
		update_btn.disabled = false
		status_label.text = "Invalid update url."
	else:
		new_major = online_version[0]
		new_minor = online_version[1]
		new_patch = online_version[2]
		
		if is_online_higher(new_major, new_minor, new_patch):
			if CURRENT_MAJOR < new_major or CURRENT_MINOR < new_minor:
				update_available_lbl.text = "Launch insert-script-file to update."
				update_btn.disabled = true
		elif FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/tagit.pck"):
			load_tagger()
			return
	
	margin_container.visible = true
	update_btn.pressed.connect(_on_download_pressed)
	skip_btn.pressed.connect(_on_skip_pressed)
	ignore_btn.pressed.connect(_on_dont_update_pressed)
	update_requester.request_completed.connect(on_request_completed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		return


func load_tagger() -> void:
	print("Loading tagger!!!!")
	return
	if FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/tagit.pck"):
		var window := get_window()
		window.size = Vector2i(1280, 720)
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		@warning_ignore("integer_division")
		window.position = Vector2i((screen_size.x - 1280) / 2, (screen_size.y - 720) / 2)
		splash.visible = true # Splashing while the main application loads.
		main_panel.visible = false
		ProjectSettings.load_resource_pack(
				OS.get_executable_path().get_base_dir() + "/tagit.pck")
		var main_scene = load("res://scenes/main_scene.tscn")
		get_tree().change_scene_to_packed(main_scene)
	else:
		update_btn.disabled = true
		ignore_btn.disabled = true
		skip_btn.disabled = true
		status_label.text = "Couldn't find \"tagit.pck\". Exiting"
		await get_tree().create_timer(5.0).timeout
		get_tree().quit()


func get_online_version() -> Array[int]:
	download_url = "http://ipv4.download.thinkbroadband.com/5MB.zip"
	return [3,0,1]
	var version_request := HTTPRequest.new()
	add_child(version_request)
	version_request.timeout = 10.0
	var error = version_request.request(
		"https://api.github.com/Ketei/repos/tagit-v3/releases/latest")
	
	var response = await version_request.request_completed
	version_request.queue_free()
	
	if error == OK and response[0] == OK and response[1] == 200:
		var json_decoder = JSON.new()
		json_decoder.parse(response[3].get_string_from_utf8())
		
		if typeof(json_decoder.data) == TYPE_DICTIONARY:
			if json_decoder.data.has_all(["tag_name", "assets"]):
				var version_text: String = json_decoder.data["tag_name"].trim_prefix("v")
				var online_version: Array[int] = []
				online_version.resize(3)
				
				var version_position: int = -1
				for version_number in version_text.split(".", false):
					version_position += 1
					if 2 < version_position:
						break
					if version_number.is_valid_int():
						online_version.insert(version_position, int(version_number))
				
				for item: Dictionary in json_decoder.data["assets"]:
					if item["name"] == "tag_it.pck":
						download_url = item["browser_download_url"]
						break
				
				return online_version
	return Array([CURRENT_MAJOR, CURRENT_MINOR, CURRENT_PATCH], TYPE_INT, &"", null)


func is_online_higher(online_major: int, online_minor: int, online_patch: int) -> bool:
	if CURRENT_MAJOR < online_major:
		return true
	elif CURRENT_MAJOR == online_major:
		if CURRENT_MINOR < online_minor:
			return true
		elif CURRENT_MINOR == online_minor:
			if CURRENT_PATCH < online_patch:
				return true
	return false


func _on_download_pressed() -> void:
	update_btn.disabled = true
	skip_btn.disabled = true
	ignore_btn.disabled = true
	status_label.text = "Dowloading Update..."
	update_requester.download_file = OS.get_executable_path().get_base_dir() + "/_tagit.pck"
	update_requester.request(download_url)


func _on_skip_pressed() -> void:
	var version_file := FileAccess.open(OS.get_executable_path().get_base_dir() + "/version", FileAccess.WRITE)
	version_file.store_string(str(new_major,".",new_minor,".",new_patch))
	version_file.close()
	load_tagger()


func _on_dont_update_pressed() -> void:
	var version_file := FileAccess.open(OS.get_executable_path().get_base_dir() + "/version", FileAccess.WRITE)
	version_file.store_string("x")
	version_file.close()
	load_tagger()


func on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "Update Failed"
		# Deleting residual files
		if FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/_tagit.pck"):
			OS.move_to_trash(OS.get_executable_path().get_base_dir() + "/_tagit.pck")
		update_btn.disabled = false
		skip_btn.disabled = false
		ignore_btn.disabled = false
		return
	
	var base_path: String = OS.get_executable_path().get_base_dir() + "/"
	
	DirAccess.rename_absolute(
		base_path + "_tagit.pck",
		base_path + "tagit.pck")
	status_label.text = "Update Successful"
	
	var version_file := FileAccess.open(OS.get_executable_path().get_base_dir() + "/version", FileAccess.WRITE)
	version_file.store_string(str(new_major,".",new_minor,".",new_patch))
	version_file.close()
	
	await get_tree().create_timer(2.0).timeout
	load_tagger()
