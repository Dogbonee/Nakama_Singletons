extends Node

var should_save_and_restore_token = true

func _ready() -> void:
	pass

func authenticate(email: String, password: String, username: String, register: bool):
	var session : NakamaSession = await Online.nakama_client.authenticate_email_async(email, password, username, register)
	if session.is_exception():
		print("Could not authenticate Nakama session %s" % session)
	else:
		Online.set_nakama_session(session)
		Online.connect_nakama_socket()
		if should_save_and_restore_token:
			save_token()
	return session

func save_token():
	var config = ConfigFile.new()
	config.set_value("Auth", "token", Online.nakama_session.token)
	config.save("user://config.cfg")
	
func load_and_restore_token():
	var config = ConfigFile.new()
	var err = config.load("user://config.cfg")
	if err != OK:
		print("Load error")
		return
	var token = config.get_value("Auth", "token")
	Online.set_nakama_session(NakamaClient.restore_session(token))
	if Online.nakama_session.is_valid():
		Online.connect_nakama_socket()
		return true
	return false
