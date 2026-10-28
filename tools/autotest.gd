extends Node
## Automated playtest. Only active when the game is launched with:  -- --autotest --shots=<folder>
## Drives the real menus with simulated key presses, plays with a simple bot and saves screenshots.

var shots := "user://autotest"
var log_lines: Array[String] = []
var bot := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	DirAccess.make_dir_recursive_absolute(shots)
	if "--bench" in OS.get_cmdline_user_args():
		_bench.call_deferred()
	else:
		_run.call_deferred()


func _log(s: String) -> void:
	print("[autotest] ", s)
	log_lines.append(s)


func wait(sec: float) -> void:
	# inside gameplay, wait in *game* time so slow test machines still see the same game moments
	var p := play()
	if p != null and not get_tree().paused:
		var end: float = p.time + sec
		var limit := Time.get_ticks_msec() + sec * 8000
		while is_instance_valid(p) and p.is_inside_tree() and p.time < end and Time.get_ticks_msec() < limit and not get_tree().paused:
			await get_tree().process_frame
		return
	await get_tree().create_timer(sec, true, false, true).timeout


var _frames := 0
var _proc_ms := 0.0


func perf() -> String:
	var s := "fps=%d avg_script_ms=%.2f" % [Engine.get_frames_per_second(), _proc_ms / maxi(_frames, 1)]
	_frames = 0
	_proc_ms = 0.0
	return s


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots, name])
	_log("shot " + name)


func key(code: Key, hold := 0.06) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await wait(hold)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await wait(0.12)


func play() -> Node:
	var s := get_tree().current_scene
	return s if s and s.has_method("debug_jump") else null


func focused() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return f.text if f is Button else "<none>"


func _process(_dt: float) -> void:
	_frames += 1
	_proc_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var p := play()
	if not bot or p == null or get_tree().paused:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("fire")
		return
	# simple bot: chase the nearest alien column, keep firing
	var target: float = p.W / 2
	var best := INF
	for a in p.aliens:
		var d: float = absf(a.pos.x - p.px) + (1080 - a.pos.y) * 0.2
		if d < best:
			best = d
			target = a.pos.x
	if p.boss != null:
		target = p.boss.x
	Input.action_release("move_left")
	Input.action_release("move_right")
	if target < p.px - 12:
		Input.action_press("move_left")
	elif target > p.px + 12:
		Input.action_press("move_right")
	Input.action_press("fire")


func _run() -> void:
	await wait(1.4)
	await shot("00_intro")
	await wait(3.6)
	await shot("01_menu")
	_log("scene after intro: " + str(get_tree().current_scene.name))
	var lvs := []
	for lv in Global.levels:
		lvs.append("%s:%d" % [lv.planet, lv.rows.size()])
	_log("level rows: " + ", ".join(lvs))
	_log("menu focus: " + focused())
	# multiplayer -> coming soon toast
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	_log("focus after 2 downs: " + focused())
	await key(KEY_ENTER)
	await wait(0.4)
	await shot("02_multiplayer_toast")
	# credits
	await key(KEY_DOWN)
	_log("focus: " + focused())
	await key(KEY_ENTER)
	await wait(0.5)
	await shot("02b_credits")
	Input.action_press("ui_down")
	await wait(1.2)
	Input.action_release("ui_down")
	await shot("02c_credits_scrolled")
	await key(KEY_ESCAPE)
	await wait(0.3)
	# changelog
	await key(KEY_DOWN)
	_log("focus: " + focused())
	await key(KEY_ENTER)
	await wait(0.5)
	await shot("02d_changelog")
	Input.action_press("ui_down")
	await wait(1.0)
	Input.action_release("ui_down")
	await shot("02e_changelog_scrolled")
	await key(KEY_ESCAPE)
	await wait(0.3)
	# options
	await key(KEY_UP)
	await key(KEY_UP)
	await key(KEY_UP)
	_log("focus: " + focused())
	await key(KEY_ENTER)
	await wait(0.5)
	await key(KEY_DOWN)
	await key(KEY_LEFT)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await shot("03_options")
	await key(KEY_ESCAPE)
	await wait(0.3)
	_log("after options focus: " + focused())
	# new game -> difficulty -> normal
	await key(KEY_UP)
	_log("focus: " + focused())
	await key(KEY_ENTER)
	await wait(0.4)
	await shot("04_difficulty")
	await key(KEY_DOWN)
	_log("difficulty focus: " + focused())
	await key(KEY_ENTER)
	await wait(1.2)
	await shot("05_intro")
	var p := play()
	_log("play scene: %s level %d lives %d" % [p != null, p.level_index, p.lives])
	p.debug_god = true
	await wait(2.6)
	bot = true
	await wait(5.0)
	await shot("06_gameplay")
	# pause menu
	await key(KEY_ESCAPE)
	await wait(0.4)
	await shot("07_pause")
	_log("paused=%s focus=%s" % [get_tree().paused, focused()])
	await key(KEY_ESCAPE)
	await wait(0.3)
	_log("after resume paused=%s" % get_tree().paused)
	# power-ups
	p.debug_give("dual")
	p.debug_give("shield")
	await wait(0.4)
	p.debug_give("speed")
	await wait(1.5)
	await shot("08_powerups")
	p.bombs = 2
	Input.action_press("bomb")
	await wait(0.05)
	Input.action_release("bomb")
	await wait(0.25)
	await shot("09_bomb")
	await wait(4.0)
	_log("mercury after bot: aliens=%d score=%d state=%s %s" % [p.aliens.size(), p.score, p.state, perf()])
	await shot("10_mercury_late")
	# every planet
	for i in range(1, 9):
		p.debug_jump(i)
		await wait(1.0)
		await shot("lvl%d_intro" % (i + 1))
		await wait(4.5)
		await shot("lvl%d_play" % (i + 1))
		_log("%s aliens=%d bullets=%d score=%d state=%s %s" % [p.lv.planet, p.aliens.size(), p.bullets.size(), p.score, p.state, perf()])
	# boss
	bot = false
	p.debug_clear_wave()
	await wait(1.0)
	await shot("20_boss_warning")
	await wait(3.0)
	bot = true
	await wait(5.0)
	await shot("21_boss_fight")
	_log("boss hp %s" % (p.boss.hp if p.boss != null else "none"))
	await wait(4.0)
	await shot("22_boss_attacks")
	if p.boss != null:
		p.debug_damage_boss(int(p.boss.hp - p.boss.max_hp / 2 + 1))
	await wait(3.0)
	await shot("23_boss_enraged")
	if p.boss != null:
		p.debug_damage_boss(int(p.boss.hp))
	await wait(1.5)
	await shot("24_boss_dying")
	await wait(6.5)
	await shot("25_victory")
	_log("state=%s score=%d high=%d save=%s" % [p.state, p.score, Global.high_score(), Global.load_game()])
	bot = false
	await key(KEY_ENTER)
	await wait(1.0)
	await shot("26_menu_after_victory")
	# save & continue flow
	Global.start_game({"level": 3, "score": 12345, "lives": 3, "bombs": 1, "difficulty": "hard"})
	await wait(1.5)
	await key(KEY_ESCAPE)
	await wait(0.3)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	_log("pause focus: " + focused())
	await key(KEY_ENTER)
	await wait(1.2)
	await shot("27_menu_continue")
	_log("menu focus: %s save=%s" % [focused(), Global.load_game()])
	await key(KEY_ENTER)
	await wait(1.5)
	p = play()
	_log("continued: level %d score %d" % [p.level_index, p.score])
	await shot("28_continued")
	# game over
	p.lives = 1
	await wait(2.5)
	p.debug_god = false
	p._kill_player()
	await wait(3.6)
	await shot("29_gameover")
	_log("state=" + p.state)
	var f := FileAccess.open(shots + "/log.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	get_tree().quit()


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
	Global.start_game({"level": 8, "score": 0, "lives": 3, "bombs": 3, "difficulty": "hard"})
	await get_tree().create_timer(0.5).timeout
	var p := play()
	p.debug_god = true
	p.state = "play"
	p.form_y = p.form_start_y
	bot = true
	p.debug_give("spread")
	p.debug_give("rapid")
	_log("pluto fleet: " + await _measure(900))
	_log("aliens=%d bullets=%d" % [p.aliens.size(), p.bullets.size()])
	p.debug_clear_wave()
	for i in 600:
		await get_tree().process_frame
		if p.boss != null and p.boss.state == "fight":
			break
	p.debug_give("dual")
	_log("boss fight: " + await _measure(900))
	_log("aliens=%d bullets=%d boss=%s" % [p.aliens.size(), p.bullets.size(), p.boss.hp if p.boss != null else "none"])
	get_tree().quit()
