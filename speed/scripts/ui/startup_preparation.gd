## 全ステージの資源取得と描画準備を、タイトルの裏で進める。
extends Node

func prepare() -> bool:
	# タイトルの最初の描画を待ってから、資源一覧の検査を始める。
	await RenderingServer.frame_post_draw
	var began := Time.get_ticks_usec()
	var scope: ContentResourceScope = await ContentManager.prepare_startup_resources()
	while not scope.is_ready() and not scope.failed and not scope.cancelled:
		await get_tree().process_frame
	ContentManager.startup_timings["startup_resource_wait_ms"] = (Time.get_ticks_usec()-began)/1000.0
	if not scope.failed and not scope.cancelled:
		var warm_began := Time.get_ticks_usec()
		load("res://scripts/render/run_presentation.gd").warm_resources(self,scope)
		while not scope.warmup_complete and not scope.failed and not scope.cancelled:
			await get_tree().process_frame
		ContentManager.startup_timings["startup_shader_warmup_ms"] = (Time.get_ticks_usec()-warm_began)/1000.0
	ContentManager.startup_timings["startup_preparation_ms"] = (Time.get_ticks_usec()-began)/1000.0
	if not scope.failed and not scope.cancelled: return true
	push_error("起動時の資源準備に失敗しました")
	return false
