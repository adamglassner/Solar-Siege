extends Node
## Automated playtest. Only active when the game is launched with:
##   -- --autotest --scenario=<single|local|editor|host|guest> --shots=<folder>
## Drives the real menus with simulated input, plays with simple bots and saves screenshots.

var shots := "user://autotest"
var scenario := "single"
var log_lines: Array[String] = []
var bot := false
var _frames := 0
var _proc_ms := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
		elif a.begins_with("--scenario="):
			scenario = a.substr(11)
	DirAccess.make_dir_recursive_absolute(shots)
	## achievements are shared with Ironite Launcher through this folder (normally %APPDATA%\Ironite\Achievements)
	OS.set_environment("IRONITE_ACHIEVEMENTS_DIR", shots.path_join("ironite_achievements"))
	if "--bench" in OS.get_cmdline_user_args():
		_bench.call_deferred()
	else:
		_go.call_deferred()


func _go() -> void:
	match scenario:
		"local":
			await _local()
		"editor":
			await _editor()
		"host":
			await _host()
		"guest":
			await _guest()
		_:
			await _single()
	_finish()


func _finish() -> void:
	var f := FileAccess.open(shots + "/log.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	get_tree().quit()


# ---------------------------------------------------------------- helpers
func _log(s: String) -> void:
	print("[autotest] ", s)
	log_lines.append(s)


func check(ok: bool, what: String) -> void:
	_log(("PASS " if ok else "FAIL ") + what)


func wait(sec: float) -> void:
	## inside gameplay, wait in *game* time so slow test machines see the same moments
	var p := play()
	if p != null and not get_tree().paused and not p.is_guest():
		var end: float = p.time + sec
		var limit := Time.get_ticks_msec() + sec * 8000
		while is_instance_valid(p) and p.is_inside_tree() and p.time < end and Time.get_ticks_msec() < limit and not get_tree().paused:
			await get_tree().process_frame
		return
	await get_tree().create_timer(sec, true, false, true).timeout


func wait_until(cond: Callable, timeout: float, what: String) -> bool:
	var limit := Time.get_ticks_msec() + timeout * 1000
	while Time.get_ticks_msec() < limit:
		if cond.call():
			return true
		await get_tree().process_frame
	_log("TIMEOUT waiting for " + what)
	return false


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])
	_log("shot " + name)


func key(code: Key, hold := 0.06) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().create_timer(hold, true, false, true).timeout
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().create_timer(0.12, true, false, true).timeout


func pad(device: int, button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().create_timer(0.06, true, false, true).timeout
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().create_timer(0.12, true, false, true).timeout


func scene_name() -> String:
	var s := get_tree().current_scene
	return s.name if s else ""


func play() -> Node:
	var s := get_tree().current_scene
	return s if s and s.has_method("debug_jump") else null


func focused() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return f.text if f is Button else ("<%s>" % f.get_class() if f else "<none>")


func press_button(label: String) -> bool:
	for b in _all_buttons(get_tree().root):
		if b.text.to_upper() == label.to_upper() and b.is_visible_in_tree():
			b.grab_focus()
			b.emit_signal("pressed")
			return true
	_log("no button " + label)
	return false


func _all_buttons(n: Node) -> Array:
	var out := []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_buttons(c))
	return out


func perf() -> String:
	var s := "fps=%d script_ms=%.2f" % [Engine.get_frames_per_second(), _proc_ms / maxi(_frames, 1)]
	_frames = 0
	_proc_ms = 0.0
	return s


func _process(_dt: float) -> void:
	_frames += 1
	_proc_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var p := play()
	if not bot or p == null or get_tree().paused:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("fire")
		if p != null:
			for q in p.pilots:
				if q.input.source == PlayerInput.Source.BOT:
					q.input.remote_fire = false
		return
	# every bot pilot (and the keyboard/any pilot) chases the nearest alien and keeps firing
	for q in p.pilots:
		var me_local: bool = q.input.source == PlayerInput.Source.ANY and (not p.is_guest() or q.idx == p.my_idx)
		if q.input.source != PlayerInput.Source.BOT and not me_local:
			continue
		var target: float = p.W / 2
		var best := INF
		for a in p.aliens:
			var d: float = absf(a.pos.x - q.x) + (1080 - a.pos.y) * 0.2
			if d < best:
				best = d
				target = a.pos.x
		if p.boss != null:
			target = p.boss.x + (q.idx - 1) * 60
		var axis := 0.0
		if target < q.x - 12:
			axis = -1.0
		elif target > q.x + 12:
			axis = 1.0
		if q.input.source == PlayerInput.Source.BOT:
			q.input.remote_axis = axis
			q.input.remote_fire = true
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if axis < 0:
				Input.action_press("move_left")
			elif axis > 0:
				Input.action_press("move_right")
			Input.action_press("fire")


func level_files_hash() -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	for f in Global.LEVEL_PATHS:
		h.update(FileAccess.get_file_as_bytes(f))
	return h.finish().hex_encode()


# ---------------------------------------------------------------- single player
func _single() -> void:
	await wait(5.0)
	await shot("s00_menu")
	check(scene_name() == "Menu", "intro leads to the main menu")
	_log("menu focus: " + focused())
	await key(KEY_ENTER) # New Game
	await wait(0.4)
	await shot("s01_difficulty")
	await key(KEY_DOWN)
	await key(KEY_ENTER) # Normal
	await wait(1.6)
	check(scene_name() == "Story", "New Game shows the story")
	await shot("s02_story1")
	await key(KEY_SPACE)
	await key(KEY_SPACE)
	await wait(1.4)
	await shot("s03_story2")
	await key(KEY_ESCAPE)
	await wait(1.5)
	var p := play()
	check(p != null and p.mode == "single" and p.pilots.size() == 1, "story skip starts a single-player game")
	p.debug_god = true
	await wait(3.0)
	bot = true
	await wait(5.0)
	await shot("s04_gameplay")
	_log("mercury: aliens=%d score=%d %s" % [p.aliens.size(), p.pilots[0].score, perf()])
	check(p.aliens.size() > 0 and p.pilots[0].score > 0, "aliens spawn and can be shot")
	p.debug_give("dual")
	p.debug_give("dual")
	p.debug_give("shield")
	for k in ["spread", "pierce", "homing", "wingman", "rapid", "speed", "warp"]:
		p.debug_give(k)
	var me = p.pilots[0]
	check(me.t("dual") > 25.0, "picking up Dual twice stacks its time (%.1fs)" % me.t("dual"))
	check(p.warp_t > 0, "Time Warp is running")
	check(Achievements.is_unlocked("fully_loaded") and Achievements.is_unlocked("arsenal"), "holding all 8 timed power-ups unlocks Fully Loaded and Arsenal")
	check(Achievements.progress("collector") >= 9, "Collector counts each power-up type once (%d of 11)" % Achievements.progress("collector"))
	await wait(1.5)
	var kinds := {}
	for i in 90:
		await get_tree().process_frame
		for b in p.bullets:
			kinds[b.kind] = true
	await shot("s05_powerups")
	_log("bullet kinds: %s  timers: %s" % [kinds.keys(), me.timers])
	check(kinds.has("pierce") and kinds.has("missile") and kinds.has("drone"), "piercing lasers, homing missiles and the wingman all fire")
	var before: float = me.t("homing")
	p.debug_jump(1)
	await wait(4.0)
	await shot("s05b_carry_over")
	check(me.t("homing") > 0 and me.t("dual") > 0 and me.t("wingman") > 0, "power-ups carry over to the next planet (homing %.1f -> %.1f)" % [before, me.t("homing")])
	var sv: Dictionary = Global.load_game()
	check(sv.has("powers") and sv.powers.size() >= 5, "the checkpoint save keeps your power-ups")
	p.debug_jump(8)
	await wait(5.5)
	check(Achievements.is_unlocked("edge_of_darkness"), "reaching Pluto unlocks The Edge of Darkness")
	p.debug_clear_wave()
	await wait(4.5)
	await wait(4.0)
	await shot("s06_boss")
	if p.boss != null:
		p.debug_damage_boss(int(p.boss.hp))
	await wait(9.0)
	await shot("s07_victory")
	check(p.state == "victory", "beating Erebus wins the campaign")
	check(Achievements.is_unlocked("sunrise") and Achievements.is_unlocked("speedrun"), "beating Erebus unlocks Sunrise and Speedrun")
	check(not Achievements.is_unlocked("no_continues") or not Achievements.is_unlocked("ringside"), "skipped planets don't count as cleared")
	_log("unlocked %d: %s" % [Achievements.unlocked_count(), Achievements.state.unlocked.keys()])
	Achievements.flush()
	var exp_path := shots.path_join("ironite_achievements/solarsiege.json")
	var ex = JSON.parse_string(FileAccess.get_file_as_string(exp_path)) if FileAccess.file_exists(exp_path) else null
	var ok_export: bool = ex is Dictionary and ex.get("game") == "solarsiege" and ex.achievements.size() == Achievements.defs.size() \
		and ex.achievements.filter(func(a): return a.unlocked).size() == Achievements.unlocked_count() \
		and FileAccess.file_exists(shots.path_join("ironite_achievements/solarsiege/sunrise.png"))
	check(ok_export, "achievements are shared with Ironite Launcher (%s)" % exp_path)
	bot = false
	await key(KEY_ENTER)
	await wait(1.0)
	check(scene_name() == "Menu", "victory returns to the menu")
	press_button("Achievements")
	await wait(0.8)
	await shot("s08_achievements")
	await key(KEY_DOWN, 1.2)
	await shot("s09_achievements_scrolled")
	await key(KEY_ESCAPE)
	await wait(0.5)
	check(scene_name() == "Menu" and focused().to_upper() == "ACHIEVEMENTS", "the Achievements page closes back to the menu")


# ---------------------------------------------------------------- same computer
func _local() -> void:
	await wait(5.0)
	await key(KEY_DOWN)
	_log("focus: " + focused())
	await key(KEY_ENTER) # Multiplayer
	await wait(1.0)
	check(scene_name() == "Lobby", "Multiplayer opens the lobby")
	await shot("l00_lobby_empty")
	await pad(0, JOY_BUTTON_A)
	await pad(1, JOY_BUTTON_A)
	await pad(1, JOY_BUTTON_RIGHT_SHOULDER)
	await pad(1, JOY_BUTTON_RIGHT_SHOULDER)
	await pad(2, JOY_BUTTON_A)
	await pad(2, JOY_BUTTON_B) # joins and leaves again
	press_button("Join with Keyboard")
	await wait(0.4)
	var lobby := get_tree().current_scene
	_log("slots: %s" % [lobby.local_slots])
	check(lobby.local_slots.size() == 3, "two controllers and the keyboard joined, a third controller left")
	var colors: Array = lobby.local_slots.map(func(s): return s.color)
	check(colors.size() == 3 and colors[0] != colors[1] and colors[1] != colors[2] and colors[0] != colors[2], "every player has a different colour")
	await shot("l01_lobby_joined")
	press_button("Start Game")
	await wait(1.5)
	check(scene_name() == "Story", "a multiplayer campaign shows the squadron story")
	await wait(1.0)
	await key(KEY_SPACE)
	await key(KEY_SPACE)
	await key(KEY_SPACE)
	await wait(1.5)
	await shot("l02_story_squadron")
	await key(KEY_ESCAPE)
	await wait(1.5)
	var p := play()
	check(p != null and p.mode == "local" and p.pilots.size() == 3, "same-computer game with 3 pilots")
	var inputs: Array = p.pilots.map(func(q): return q.input.label())
	_log("inputs: %s" % [inputs])
	check(inputs == ["Controller 1", "Controller 2", "Keyboard"], "each pilot has their own controls")
	for q in p.pilots:
		q.input = PlayerInput.bot()
	p.debug_god = true
	await wait(2.0)
	await shot("l03_intro")
	bot = true
	await wait(6.0)
	await shot("l04_gameplay")
	var scores: Array = p.pilots.map(func(q): return q.score)
	_log("scores %s %s" % [scores, perf()])
	check(scores.filter(func(s): return s > 0).size() >= 2, "several pilots score")
	p.debug_give("dual", 0)
	p.debug_give("speed", 1)
	p.debug_give("shield", 2)
	p.debug_give("wingman", 1)
	p.debug_give("homing", 2)
	p.debug_give("pierce", 0)
	p.debug_give("warp", 0)
	await wait(1.5)
	await shot("l05_powerups")
	# one pilot loses all lives, then an extra ship revives them
	p.pilots[1].lives = 1
	p.debug_kill(1)
	await wait(2.0)
	check(p.pilots[1].out(), "a pilot with no lives is out")
	await shot("l06_pilot_out")
	p.debug_god = true
	p.debug_give("life", 0)
	await wait(1.5)
	check(p.pilots[1].alive, "an Extra Ship revives the downed wingmate")
	p.debug_jump(8)
	await wait(5.5)
	p.debug_clear_wave()
	await wait(9.0)
	await shot("l07_boss")
	_log("boss hp %s" % (p.boss.hp if p.boss != null else "none"))
	for q in p.pilots:
		q.lives = 1
	bot = false
	for i in 3:
		p.debug_kill(i)
	await wait(4.0)
	await shot("l08_gameover")
	check(p.state == "gameover", "game over when every pilot is out")
	press_button("Main Menu")
	await wait(1.0)


# ---------------------------------------------------------------- level editor
func _editor() -> void:
	var before := level_files_hash()
	await wait(5.0)
	Global.goto_scene("res://scenes/maps.tscn")
	await wait(1.0)
	await shot("e00_maps")
	var maps := CustomMaps.list()
	check(maps.size() >= 2, "example maps are installed")
	press_button("New Map")
	await wait(1.0)
	check(scene_name() == "Editor", "New Map opens the editor")
	var ed := get_tree().current_scene
	var grid: EditorGrid = ed._grid
	# paint with the mouse: click and drag along a row
	for c in range(2, 11):
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = Vector2(c * 84 + 40, 3 * 84 + 40)
		grid._gui_input(e)
		var u := e.duplicate()
		u.pressed = false
		grid._gui_input(u)
	# keyboard tools: 6 = cruiser, 5 = wraith
	ed._select_tool(5)
	grid.put(Vector2i(3, 0), "cruiser")
	grid.put(Vector2i(8, 0), "cruiser")
	ed._select_tool(4)
	for c in range(1, 12):
		grid.put(Vector2i(c, 1), "wraith")
	grid.put(Vector2i(6, 2), "squid")
	ed._set_option("backdrop", 4)
	ed._choices.backdrop.set_options(ed._choices.backdrop.options, 4)
	ed._set_option("boss", 1)
	ed._choices.boss.set_options(ed._choices.boss.options, 1)
	ed._set_option("shields", 2)
	ed._choices.shields.set_options(ed._choices.shields.options, 2)
	ed._name.text = "Test Gauntlet"
	ed.map.name = "Test Gauntlet"
	await wait(0.5)
	_log("map aliens: %d (mouse row: %s)" % [CustomMaps.count_aliens(ed.map), ed.map.grid[3]])
	check(CustomMaps.count_aliens(ed.map) == 2 + 11 + 1 + 9, "painting by mouse, keyboard tools and API all place aliens")
	await shot("e01_editor")
	check(ed._save(), "the map saves")
	var saved := CustomMaps.load_map(ed.path)
	check(saved.name == "Test Gauntlet" and saved.boss and saved.shields == 2, "the saved file has the settings")
	press_button("Test Play")
	await wait(1.5)
	var p := play()
	check(p != null and p.lv.custom and p.aliens.size() == 23, "test play builds the custom formation")
	p.debug_god = true
	await wait(3.2)
	bot = true
	await wait(3.0)
	await shot("e02_testplay")
	bot = false
	p.debug_clear_wave()
	await wait(4.0)
	await wait(4.0)
	await shot("e03_custom_boss")
	if p.boss != null:
		p.debug_damage_boss(int(p.boss.hp))
	await wait(9.0)
	await shot("e04_map_complete")
	check(p.state == "victory", "clearing a custom map shows Map Complete")
	press_button("Back to Editor")
	await wait(1.0)
	check(scene_name() == "Editor", "Back to Editor returns to the editor")
	await shot("e05_back_in_editor")
	press_button("Back")
	await wait(1.0)
	check(scene_name() == "Maps", "Back returns to Custom Maps")
	await wait(0.5)
	await shot("e06_maps_with_new")
	check(level_files_hash() == before, "the nine campaign level files are untouched")
	check(Global.load_game().is_empty(), "custom maps don't create a campaign save")


# ---------------------------------------------------------------- online
func _host() -> void:
	await wait(5.0)
	Global.settings.name = "Hosty"
	Global.settings.color = 3
	Global.lobby_memory = {"tab": "online", "game_index": 0, "diff_index": 1}
	Global.goto_scene("res://scenes/lobby.tscn")
	await wait(1.0)
	await shot("h00_online_tab")
	press_button("Host a Game")
	await wait(0.5)
	check(Net.is_host(), "hosting opens the port")
	await shot("h01_hosting")
	var ok := await wait_until(func(): return Net.players.size() >= 2, 40.0, "the guest to join")
	check(ok, "a guest joined")
	await wait(1.0)
	await shot("h02_lobby_two")
	_log("players: %s" % [Net.players])
	check(Net.players.size() == 2 and Net.players[0].color != Net.players[1].color, "pilots have different colours")
	press_button("Start Game")
	await wait(2.0)
	check(scene_name() == "Story", "host shows the story")
	await shot("h03_story")
	await wait(3.0)
	await key(KEY_ESCAPE)
	await wait(2.0)
	var p := play()
	check(p != null and p.role == "host" and p.pilots.size() == 2, "online game started on the host")
	p.debug_god = true
	await wait(3.5)
	bot = true
	await wait(8.0)
	await shot("h04_gameplay")
	var g = p.pilots[1]
	_log("guest pilot x=%.0f score=%d alive=%s %s" % [g.x, g.score, g.alive, perf()])
	check(g.score > 0, "the guest's shots count on the host")
	for k in ["wingman", "homing", "pierce", "dual", "warp"]:
		p.debug_give(k, 1)
	await wait(3.0)
	await shot("h04b_guest_powers")
	p.debug_jump(8)
	await wait(5.5)
	p.debug_clear_wave()
	await wait(9.0)
	await shot("h05_boss")
	if p.boss != null:
		p.debug_damage_boss(int(p.boss.hp))
	await wait(9.5)
	await shot("h06_victory")
	check(p.state == "victory", "online victory")
	check(Achievements.is_unlocked("team_player"), "the host unlocks Team Player")
	bot = false
	await wait(3.0)
	press_button("Back to Lobby")
	await wait(2.0)
	check(scene_name() == "Lobby", "host is back in the lobby")
	await shot("h07_back_in_lobby")
	ok = await wait_until(func(): return Net.players.size() == 1, 30.0, "the guest to leave")
	check(ok, "the host sees the guest leave")
	await wait(1.0)
	await shot("h08_guest_left")
	Net.leave()


func _guest() -> void:
	await wait(5.0)
	Global.settings.name = "Guesty"
	Global.settings.color = 3 # same as the host: the host must hand out another colour
	Global.lobby_memory = {"tab": "online"}
	Global.goto_scene("res://scenes/lobby.tscn")
	await wait(1.5)
	var lobby := get_tree().current_scene
	lobby._addr_edit.text = "127.0.0.1"
	press_button("Join a Game")
	var ok := await wait_until(func(): return Net.players.size() >= 2, 40.0, "the lobby list")
	check(ok, "guest joined the host's lobby")
	await wait(1.0)
	await shot("g00_lobby")
	_log("players: %s me=%d" % [Net.players, Net.my_id])
	ok = await wait_until(func(): return scene_name() == "Story", 60.0, "the story")
	check(ok, "guest follows the host into the story")
	await wait(1.0)
	await shot("g01_story")
	ok = await wait_until(func(): return play() != null, 60.0, "the game")
	check(ok, "guest follows the host into the game")
	var p := play()
	check(p.role == "guest" and p.pilots.size() == 2 and p.pilots[p.my_idx].name == "Guesty", "guest flies its own pilot")
	await wait(3.5)
	bot = true
	await wait(8.0)
	await shot("g02_gameplay")
	_log("guest view: aliens=%d bullets=%d my score=%d host score=%d" % [p.aliens.size(), p.bullets.size(), p.pilots[p.my_idx].score, p.pilots[0].score])
	check(p.aliens.size() > 0, "guest sees the formation")
	var mine = p.pilots[p.my_idx]
	ok = await wait_until(func(): return mine.t("wingman") > 0 and p.warp_t > 0, 15.0, "power-ups from the host")
	var seen := {}
	for i in 90:
		await get_tree().process_frame
		for b in p.bullets:
			seen[b.kind] = true
	await shot("g02b_powers")
	_log("guest powers: %s warp=%.1f shots=%s" % [mine.timers, p.warp_t, seen.keys()])
	check(ok and seen.has("missile") and seen.has("drone") and seen.has("pierce"), "guest gets its power-ups, Time Warp and sees missiles, drone and piercing shots")
	ok = await wait_until(func(): return p.boss != null, 60.0, "the boss")
	await wait(2.0)
	await shot("g03_boss")
	check(ok and p.lv.planet == "Pluto", "guest follows the host to Pluto and sees the boss")
	ok = await wait_until(func(): return p.state == "victory", 60.0, "victory")
	await wait(2.5)
	await shot("g04_victory")
	check(ok, "guest sees the victory")
	await wait(0.5)
	_log("guest achievements: %s collector=%d" % [Achievements.state.unlocked.keys(), Achievements.progress("collector")])
	check(Achievements.progress("collector") >= 4 and Achievements.progress("all_colours") >= 1, "the guest earns its own power-up and colour progress")
	check(Achievements.is_unlocked("team_player") and Achievements.is_unlocked("sunrise"), "the guest unlocks Team Player and Sunrise from the host's game")
	bot = false
	ok = await wait_until(func(): return scene_name() == "Lobby", 60.0, "the lobby")
	check(ok, "guest follows the host back to the lobby")
	await wait(1.0)
	await shot("g05_back_in_lobby")
	press_button("Leave")
	await wait(2.0)


# ---------------------------------------------------------------- benchmark
func _measure(frames: int) -> String:
	var t0 := Time.get_ticks_usec()
	var worst := 0
	var last := t0
	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	return "avg %.2f ms/frame, worst %.2f ms" % [(Time.get_ticks_usec() - t0) / 1000.0 / frames, worst / 1000.0]


func _bench() -> void:
	Global.start_game({"mode": "local", "level": 8, "difficulty": "hard", "players": [
		{"name": "A", "color": 0, "input": "bot"}, {"name": "B", "color": 1, "input": "bot"},
		{"name": "C", "color": 2, "input": "bot"}, {"name": "D", "color": 3, "input": "bot"}]})
	await get_tree().create_timer(0.5).timeout
	var p := play()
	p.debug_god = true
	p.state = "play"
	p.form_y = p.form_start_y
	bot = true
	for i in 4:
		p.debug_give("spread", i)
		p.debug_give("rapid", i)
	_log("4 pilots, pluto fleet: " + await _measure(900))
	_log("aliens=%d bullets=%d" % [p.aliens.size(), p.bullets.size()])
	p.debug_clear_wave()
	for i in 600:
		await get_tree().process_frame
		if p.boss != null and p.boss.state == "fight":
			break
	_log("4 pilots, boss fight: " + await _measure(900))
	_finish()
