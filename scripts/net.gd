extends Node
## Online play, the same way as Chess, Checkers and the card games: one player hosts,
## up to three friends join by IP address (UDP port 47040), on a home network or over
## the internet. The host's game is the referee: it runs the battle and sends everyone
## what is happening ~30 times a second. Each guest sends the host its controls.

signal lobby_changed
signal failed(why: String)
signal story_received(players: Array)
signal start_received(start: Dictionary)
signal game_message(m: Dictionary, from: int)
signal peer_left(name: String)
signal host_left
signal returned_to_lobby

const PORT := 47040
const PROTO := 1
const MAX_PLAYERS := 4
const CH_RELIABLE := 0
const CH_FAST := 1

var role := "" # "", "host", "guest"
var peer: ENetMultiplayerPeer
var my_id := 1
var players: Array = [] # [{id, name, color}] in join order (host first)
var lobby := {"kind": "campaign", "map": {}, "difficulty": "normal"}
var in_game := false
var _hello_sent := false
var _join_deadline := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func active() -> bool:
	return role != ""


func is_host() -> bool:
	return role == "host"


# ---------------------------------------------------------------- start / stop
func host(name: String, color: int) -> String:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1, 2)
	if err != OK:
		peer = null
		return "Couldn't open port %d for friends to join (it may already be in use)." % PORT
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	role = "host"
	my_id = 1
	players = [{"id": 1, "name": clean_name(name, "Host"), "color": color}]
	in_game = false
	lobby_changed.emit()
	return ""


func join(name: String, color: int, address: String) -> String:
	leave()
	address = address.strip_edges()
	var port := PORT
	if address.count(":") == 1:
		port = int(address.get_slice(":", 1))
		address = address.get_slice(":", 0)
	if address == "":
		return "Type the host's address first. They'll see it on their screen when they choose Host a Game."
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port, 2)
	if err != OK:
		peer = null
		return "That address doesn't look right."
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	role = "guest"
	players = [{"id": 0, "name": clean_name(name, "Pilot"), "color": color}]
	in_game = false
	_hello_sent = false
	_join_deadline = Time.get_ticks_msec() + 9000
	lobby_changed.emit()
	return ""


func leave() -> void:
	if peer != null:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			send_all({"t": "bye"})
			peer.poll()
		peer.close()
	peer = null
	role = ""
	players = []
	in_game = false


# ---------------------------------------------------------------- sending
func send_to(id: int, m: Dictionary, reliable := true) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(id)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	peer.transfer_channel = CH_RELIABLE if reliable else CH_FAST
	peer.put_packet(var_to_bytes(m))


func send_all(m: Dictionary, reliable := true) -> void:
	send_to(0, m, reliable) # 0 = everyone (for a guest that's just the host)


func send_host(m: Dictionary, reliable := true) -> void:
	send_to(1, m, reliable)


# ---------------------------------------------------------------- host actions
func set_lobby(kind: String, map: Dictionary, difficulty: String) -> void:
	lobby = {"kind": kind, "map": map, "difficulty": difficulty}
	_broadcast_lobby()


func set_my_color(color: int) -> void:
	if is_host():
		if _color_free(color, 1):
			players[0].color = color
			_broadcast_lobby()
	elif role == "guest":
		send_host({"t": "color", "color": color})


func start_story(start: Dictionary) -> void:
	in_game = true
	send_all({"t": "story", "players": start.get("players", [])})


func start_game(start: Dictionary) -> void:
	in_game = true
	send_all({"t": "start", "start": start})


func back_to_lobby() -> void:
	in_game = false
	send_all({"t": "lobby_return"})
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	if is_host():
		send_all({"t": "lobby", "players": players, "lobby": _lobby_summary()})
		lobby_changed.emit()


func _lobby_summary() -> Dictionary:
	return {"kind": lobby.kind, "map_name": lobby.map.get("name", ""), "difficulty": lobby.difficulty}


func _color_free(color: int, except_id: int) -> bool:
	for p in players:
		if p.id != except_id and p.color == color:
			return false
	return true


func _free_color(want: int) -> int:
	for i in Global.SHIP_COLORS.size():
		var c := (want + i) % Global.SHIP_COLORS.size()
		if _color_free(c, -1):
			return c
	return want


func player_name(id: int) -> String:
	for p in players:
		if p.id == id:
			return p.name
	return "A friend"


# ---------------------------------------------------------------- receiving
func _process(_dt: float) -> void:
	if peer == null:
		return
	peer.poll()
	if peer == null:
		return
	if role == "guest" and not _hello_sent:
		var st := peer.get_connection_status()
		if st == MultiplayerPeer.CONNECTION_CONNECTED:
			_hello_sent = true
			my_id = peer.get_unique_id()
			send_host({"t": "hello", "name": players[0].name, "color": players[0].color, "proto": PROTO, "ver": Global.version()})
		elif st == MultiplayerPeer.CONNECTION_DISCONNECTED or Time.get_ticks_msec() > _join_deadline:
			_fail("Couldn't reach that address. Check it with your friend, and that their game is waiting in Host a Game.")
			return
	while peer != null and peer.get_available_packet_count() > 0:
		var from := peer.get_packet_peer()
		var m = bytes_to_var(peer.get_packet())
		if typeof(m) == TYPE_DICTIONARY and m.has("t"):
			_handle(m, from)


func _handle(m: Dictionary, from: int) -> void:
	match m.t:
		"hello":
			if not is_host():
				return
			if m.get("proto", 0) != PROTO or str(m.get("ver", "")) != Global.version():
				_refuse(from, "Your friend has a different version of Solar Siege (%s). Both players need the same version." % Global.version())
				return
			if in_game:
				_refuse(from, "That game has already started.")
				return
			if players.size() >= MAX_PLAYERS:
				_refuse(from, "That game already has four pilots.")
				return
			var p := {"id": from, "name": clean_name(str(m.get("name", "")), "Pilot %d" % (players.size() + 1)), "color": _free_color(int(m.get("color", 0)))}
			players.append(p)
			send_to(from, {"t": "welcome", "id": from})
			Audio.play("menu_select")
			_broadcast_lobby()
		"color":
			if is_host():
				var c := int(m.get("color", 0))
				if _color_free(c, from):
					for p in players:
						if p.id == from:
							p.color = c
				_broadcast_lobby()
		"welcome":
			my_id = int(m.id)
		"refuse":
			_fail(str(m.get("why", "The host turned the connection away.")))
		"lobby":
			if role == "guest":
				players = m.players
				lobby = {"kind": m.lobby.kind, "map": {"name": m.lobby.map_name}, "difficulty": m.lobby.difficulty}
				lobby_changed.emit()
		"lobby_return":
			in_game = false
			returned_to_lobby.emit()
			lobby_changed.emit()
		"story":
			if role == "guest":
				in_game = true
				story_received.emit(m.get("players", []))
		"start":
			if role == "guest":
				in_game = true
				start_received.emit(m.start)
		"bye":
			_on_peer_disconnected(from)
		_:
			game_message.emit(m, from)


func _refuse(id: int, why: String) -> void:
	send_to(id, {"t": "refuse", "why": why})
	peer.poll()
	peer.disconnect_peer(id, false)


func _on_peer_connected(_id: int) -> void:
	pass # wait for its hello


func _on_peer_disconnected(id: int) -> void:
	if role == "guest":
		var was_connected := _hello_sent
		leave()
		if was_connected:
			host_left.emit()
		else:
			failed.emit("Couldn't reach that address.")
		lobby_changed.emit()
		return
	for i in players.size():
		if players[i].id == id:
			var name: String = players[i].name
			players.remove_at(i)
			peer_left.emit(name)
			_broadcast_lobby()
			return


func _fail(why: String) -> void:
	leave()
	failed.emit(why)
	lobby_changed.emit()


# ---------------------------------------------------------------- helpers
static func clean_name(s: String, def: String) -> String:
	s = s.strip_edges()
	if s.length() > 14:
		s = s.substr(0, 14)
	return s if s != "" else def


## This computer's network addresses, for the host to share (home network first).
static func local_ips() -> Array:
	var out := []
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		out.append(ip)
	out.sort_custom(func(a, b): return a.begins_with("192.168.") and not b.begins_with("192.168."))
	return out.slice(0, 3)
