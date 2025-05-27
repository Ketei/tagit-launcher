extends Control


var current_major: int = 3
var current_minor: int = 4
var current_patch: int = 0

var new_major: int = current_major
var new_minor: int = current_minor
var new_patch: int = current_patch

var download_url: String = ""
var downloading_pck: bool = false
var progress_tracking: int = 0

@onready var update_requester: HTTPRequest = $UpdateRequester
@onready var update_btn: Button = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/ButtonContainer/UpdateBtn
@onready var skip_btn: Button = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/ButtonContainer/SkipBtn
@onready var ignore_btn: Button = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/ButtonContainer/IgnoreBtn
@onready var status_label: Label = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/StatusLabel
@onready var update_available_lbl: Label = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/UpdateAvailableLbl
@onready var margin_container: MarginContainer = $MainPanel/MainContainer/DataContainer/MarginContainer
@onready var main_panel: PanelContainer = $MainPanel
@onready var download_progress: ProgressBar = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/PanelContainer/DownloadProgress
@onready var continue_button: Button = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/PathContainer/ContinueButton
@onready var exit_button: Button = $MainPanel/MainContainer/DataContainer/MarginContainer/InfoContainer/PathContainer/ExitButton


func _ready() -> void:
	SingletonManager.singletons_ready.connect(_on_singletons_ready)
	set_process(false)
	download_progress.visible = false
	get_window().title = "TagIt!"
	margin_container.visible = false
	
	await get_tree().create_timer(0.50).timeout
	
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	
	for arg in arguments:
		if arg.begins_with("--update-launcher"):
			download_progress.visible = true
			await update_launcher(arg.get_slice("=", 1))
			download_progress.value = 0
			download_progress.visible = false
			break
	
	if arguments.has("--no-update") and FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/tagit.pck"):
		load_tagger()
		return
	
	var version_file = FileAccess.open(OS.get_executable_path().get_base_dir() + "/version", FileAccess.READ)
	
	var version_text: String = version_file.get_as_text().strip_edges().to_lower() if version_file != null else ""
	
	if not version_text.is_empty():
		if version_text == "x":
			load_tagger()
			return
		else:
			var split_string: PackedStringArray = version_text.split(".", false)
			if split_string.size() == 3:
				var version_idx: int = -1
				var version_array: Array[int] = [current_major, current_minor, current_patch]
				for item in split_string:
					version_idx += 1
					if 2 < version_idx:
						break
					if item.is_valid_int():
						version_array[version_idx] = int(item)
				current_major = version_array[0]
				current_minor = version_array[1]
				current_patch = version_array[2]
	
	var online_version: Array[int] = await get_online_version()
	
	if download_url.is_empty():
		update_btn.disabled = true
		status_label.text = "Invalid update url."
	else:
		new_major = online_version[0]
		new_minor = online_version[1]
		new_patch = online_version[2]
		
		if is_online_higher(new_major, new_minor, new_patch):
			if current_major < new_major or current_minor < new_minor:
				update_available_lbl.text = "Run with launcher to update."
				update_btn.disabled = true
		elif FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/tagit.pck"):
			load_tagger()
			return
	
	continue_button.disabled = not FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/tagit.pck")
	margin_container.visible = true
	
	exit_button.pressed.connect(_on_exit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	update_btn.pressed.connect(_on_download_pressed)
	skip_btn.pressed.connect(_on_skip_pressed)
	ignore_btn.pressed.connect(_on_dont_update_pressed)
	update_requester.request_completed.connect(_on_request_completed)


func _process(_delta: float) -> void:
	if download_progress.value != update_requester.get_downloaded_bytes():
		download_progress.value = update_requester.get_downloaded_bytes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_exit_pressed()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:
	load_tagger()


func load_tagger() -> void:
	update_btn.disabled = true
	ignore_btn.disabled = true
	skip_btn.disabled = true
	continue_button.disabled = true
	
	if FileAccess.file_exists(OS.get_executable_path().get_base_dir() + "/tagit.pck"):
		var successful_loading: bool = ProjectSettings.load_resource_pack(
				OS.get_executable_path().get_base_dir() + "/tagit.pck")
		
		if not successful_loading:
			push_error("PCK loading returned false.")
			status_label.text = "Couldn't load \"tagit.pck\". Exiting."
			await get_tree().create_timer(5.0).timeout
			get_tree().quit()
		else:
			SingletonManager.reload_singletons()
		
	else:
		push_error("PCK not found at: " + OS.get_executable_path().get_base_dir() + "/tagit.pck")
		status_label.text = "Couldn't find \"tagit.pck\". Exiting"
		await get_tree().create_timer(5.0).timeout
		get_tree().quit()


func _on_singletons_ready() -> void:
	var window := get_window()
	window.size = Vector2i(1280, 720)
	window.move_to_center()
	window.borderless = false
	window.unresizable = false
	main_panel.visible = false
	SingletonManager.TagIt.show_splash()
	
	await get_tree().create_timer(0.5).timeout
	
	var main_scene = load("res://scenes/main_scene.tscn")
	get_tree().change_scene_to_packed(main_scene)


func get_online_version() -> Array[int]:
	var version_request := HTTPRequest.new()
	add_child(version_request)
	version_request.timeout = 10.0
	var error = version_request.request(
		"https://api.github.com/repos/Ketei/tagit-launcher/releases/latest")
	
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
					if item["name"] == "tagit.pck":
						download_url = item["browser_download_url"]
						download_progress.max_value = item["size"]
						break
				
				return online_version
	return Array([current_major, current_minor, current_patch], TYPE_INT, &"", null)


func update_launcher(launcher_path: String) -> void:
	var launcher_http := HTTPRequest.new()
	add_child(launcher_http)
	launcher_http.timeout = 10.0
	var error = launcher_http.request(
		"https://api.github.com/repos/Ketei/tagit-v3/releases/latest")
	
	var response = await launcher_http.request_completed
	launcher_http.queue_free()
	if error == OK and response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
		var json_decoder = JSON.new()
		json_decoder.parse(response[3].get_string_from_utf8())
		
		if typeof(json_decoder.data) != TYPE_DICTIONARY or not json_decoder.data.has("assets"):
			push_error("Couldn't update launcher: ", typeof(json_decoder.data),"/","false" if typeof(json_decoder.data) == TYPE_DICTIONARY else "null")
			return
		
		var ext: String = launcher_path.get_extension().to_lower()
		
		if ext == "bat" or ext == "sh":
			ext = "exe" if ext == "bat" else ""
			launcher_path = launcher_path.get_basename()
			if not ext.is_empty():
				launcher_path += "." + ext
		
		var target_launcher: String = "tagit-launcher.exe" if ext == "exe" else "tagit-launcher"
		
		var launcher_url: String = ""
		
		for item: Dictionary in json_decoder.data["assets"]:
			if item["name"] == target_launcher:
				launcher_url = item["browser_download_url"]
				download_progress.max_value = item["size"]
				break
		
		if launcher_url.is_empty():
			return
		
		var base_dir: String = ProjectSettings.globalize_path("user://")
		
		if not base_dir.ends_with("/"):
			base_dir += "/"
		
		update_requester.download_file = base_dir + "_launcher"
		status_label.text = "Updating Launcher"
		
		# Making a timer so we can monitor the download. If it stalls, we cancel it.
		var fallback_timer: Timer = Timer.new()
		fallback_timer.wait_time = 5.0
		fallback_timer.autostart = true
		fallback_timer.one_shot = false
		
		# Timer will check if the download is progressing. If not, it'll cancel it
		# and continue.
		fallback_timer.timeout.connect(_on_file_request_timeout)
		add_child(fallback_timer)
		set_process(true) # Enable process to display download progress.
		update_requester.request(launcher_url)
		var results: Array = await update_requester.request_completed
		set_process(false)
		if not fallback_timer.is_stopped():
			fallback_timer.stop()
			fallback_timer.timeout.disconnect(_on_file_request_timeout)
			fallback_timer.queue_free()
		
		if results[0] != HTTPRequest.RESULT_SUCCESS or results[1] != 200:
			push_error("Error downloading launcher: ", results[0], "/", results[1])
			# Removing residual files on failure
			if FileAccess.file_exists(base_dir + "_launcher." + ext):
				OS.move_to_trash(base_dir + "_launcher." + ext)
		else:
			var op_status: int = DirAccess.rename_absolute(
					base_dir + "_launcher." + ext,
					launcher_path)
			if op_status == OK:
				print("Launcher updated successfully!")
				status_label.text = "Launcher updated to version " + str(json_decoder.data["tag_name"])
			else:
				var status_string: String = str("Couldn't update launcher (Error: ", error_string(op_status), ")")
				print(status_string)
				status_label.text = status_string
				if FileAccess.file_exists(base_dir + "_launcher." + ext):
					OS.move_to_trash(base_dir + "_launcher." + ext)


func _on_file_request_timeout() -> void:
	if progress_tracking == update_requester.get_downloaded_bytes():
		update_requester.cancel_request()
		update_requester.request_completed.emit(
				HTTPRequest.RESULT_REQUEST_FAILED,
				0,
				PackedStringArray(),
				PackedByteArray())
	else:
		progress_tracking = update_requester.get_downloaded_bytes()
	


func is_online_higher(online_major: int, online_minor: int, online_patch: int) -> bool:
	if current_major < online_major:
		return true
	elif current_major == online_major:
		if current_minor < online_minor:
			return true
		elif current_minor == online_minor:
			if current_patch < online_patch:
				return true
	return false


func _on_download_pressed() -> void:
	if downloading_pck:
		if is_processing():
			set_process(false)
			download_progress.visible = false
			download_progress.value = 0
		update_requester.cancel_request()
		download_progress.value = 0
		update_btn.text = "Update"
		skip_btn.disabled = true
		ignore_btn.disabled = true
	else:
		update_btn.text = "Cancel"
		skip_btn.disabled = true
		ignore_btn.disabled = true
		status_label.text = "Dowloading Update..."
		if 0 < download_progress.max_value:
			set_process(true)
			download_progress.visible = true
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


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	download_progress.value = download_progress.max_value
	set_process(false)
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
