extends Node

# For developers to set from the outside, for example:
#   Online.nakama_host = 'nakama.example.com'
#   Online.nakama_scheme = 'https'
var nakama_server_key: String = 'defaultkey'
var nakama_host: String = '127.0.0.1'
var nakama_port: int = 7350
var nakama_scheme: String = 'http'

# For other scripts to access:
var nakama_client: NakamaClient : get = get_nakama_client
var nakama_session: NakamaSession : set = set_nakama_session
var nakama_socket: NakamaSocket

var multiplayer_bridge : NakamaMultiplayerBridge
var valid_bridge = false

var current_match : NakamaRTAPI.Match

# Internal variable for initializing the socket.
var _nakama_socket_connecting := false

signal session_changed (nakama_session)
signal session_connected (nakama_session)
signal socket_connected (nakama_socket)
signal game_joined (_match)

func _set_readonly_variable(_value) -> void:
	pass

func _ready() -> void:
	# Don't stop processing messages from Nakama when the game is paused.
	Nakama.process_mode = Node.PROCESS_MODE_ALWAYS
	

func get_nakama_client() -> NakamaClient:
	if nakama_client == null:
		nakama_client = Nakama.create_client(
			nakama_server_key,
			nakama_host,
			nakama_port,
			nakama_scheme,
			Nakama.DEFAULT_TIMEOUT,
			NakamaLogger.LOG_LEVEL.ERROR)
	return nakama_client

func set_nakama_session(_nakama_session: NakamaSession) -> void:
	# Close out the old socket.
	if nakama_socket:
		nakama_socket.close()
		nakama_socket = null

	nakama_session = _nakama_session

	emit_signal("session_changed", nakama_session)

	if nakama_session and not nakama_session.is_exception() and not nakama_session.is_expired():
		emit_signal("session_connected", nakama_session)

func connect_nakama_socket() -> void:
	if nakama_socket != null:
		return
	if _nakama_socket_connecting:
		return
	_nakama_socket_connecting = true

	var new_socket = Nakama.create_socket_from(nakama_client)
	await new_socket.connect_async(nakama_session)
	nakama_socket = new_socket
	_nakama_socket_connecting = false
	
	
	#connect signals
	nakama_socket.received_matchmaker_matched.connect(_on_matchmaker_matched)
	multiplayer_bridge = NakamaMultiplayerBridge.new(nakama_socket)
	multiplayer_bridge.match_joined.connect(self._on_match_joined)
	get_tree().get_multiplayer().set_multiplayer_peer(multiplayer_bridge.multiplayer_peer)
	emit_signal("socket_connected", nakama_socket)

func is_nakama_socket_connected() -> bool:
	return nakama_socket != null && nakama_socket.is_connected_to_host()
	
func find_match():
	var matchmaker_ticket : NakamaRTAPI.MatchmakerTicket = await nakama_socket.add_matchmaker_async()
	if matchmaker_ticket.is_exception():
		print("An error occurred: %s" % matchmaker_ticket)
		return
	print("Got ticket: %s" % [matchmaker_ticket])
	
	multiplayer_bridge.start_matchmaking(matchmaker_ticket)

func _on_matchmaker_matched(p_matched : NakamaRTAPI.MatchmakerMatched):
	print("Received MatchmakerMatched message: %s" % [p_matched])
	print("Matched opponents: %s" % [p_matched.users])
	join_match(p_matched)
	

func join_match(p_matched : NakamaRTAPI.MatchmakerMatched):
	var joined_match : NakamaRTAPI.Match = await nakama_socket.join_matched_async(p_matched)
	current_match = joined_match
	
func _on_match_joined():
	valid_bridge = true
	get_tree().get_multiplayer().peer_connected.connect(self._on_peer_connected)
	get_tree().get_multiplayer().peer_disconnected.connect(self._on_peer_disconnected)
	game_joined.emit(current_match)

func _on_peer_connected(peer_id):
	print ("Peer joined match: ", peer_id)

func _on_peer_disconnected(peer_id):
	print ("Peer left match: ", peer_id)
