## 起動時の資源取得と描画準備。戦闘のSessionを作らず、完了後にタイトルへ進む。
extends CanvasLayer

func prepare() -> bool:
	layer = 1000
	var background := ColorRect.new()
	background.color = Color(0.025,0.03,0.05)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)
	var status := Label.new()
	status.text = tr("loading.resources")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.x = 320
	progress.indeterminate = true
	column.add_child(progress)
	# 一覧の読取や資源要求より先に、ロード画面を一度表示する。
	await RenderingServer.frame_post_draw
	var began := Time.get_ticks_usec()
	var scope: ContentResourceScope = await ContentManager.prepare_startup_resources()
	progress.indeterminate = false
	while not scope.is_ready() and not scope.failed and not scope.cancelled:
		progress.value = scope.progress()*100.0
		await get_tree().process_frame
	ContentManager.startup_timings["startup_resource_wait_ms"] = (Time.get_ticks_usec()-began)/1000.0
	if not scope.failed and not scope.cancelled:
		status.text = tr("loading.graphics")
		var warm_began := Time.get_ticks_usec()
		load("res://scripts/render/run_presentation.gd").warm_resources(self,scope)
		while not scope.warmup_complete and not scope.failed and not scope.cancelled:
			progress.value = scope.warmup_progress*100.0
			await get_tree().process_frame
		ContentManager.startup_timings["startup_shader_warmup_ms"] = (Time.get_ticks_usec()-warm_began)/1000.0
	ContentManager.startup_timings["startup_preparation_ms"] = (Time.get_ticks_usec()-began)/1000.0
	if not scope.failed and not scope.cancelled: return true
	status.text = tr("loading.failed")
	progress.hide()
	var close := Button.new()
	close.text = tr("menu.quit")
	close.pressed.connect(func(): get_tree().quit())
	column.add_child(close)
	push_error("起動時の資源準備に失敗しました")
	return false
