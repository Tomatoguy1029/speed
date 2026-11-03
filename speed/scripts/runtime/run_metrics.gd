## 性能の累積値から、読む人ごとに独立した区間を作る。
extends RefCounted

static func window(current: Dictionary, previous: Dictionary, frames: int, elapsed_us: int) -> Dictionary:
	var baseline: Dictionary = previous if previous.get("epoch")==current.get("epoch") else {}
	var timings := {}
	var measured_us := 0
	for key in ["sim","output_build","bridge_copy","view_update","view_draw","resource_wait"]:
		if not current.get("timings",{}).has(key):
			timings[key] = null
			continue
		var value: Array = current.timings[key]
		var before: Array = baseline.get("timings",{}).get(key,[0,0,0])
		var total := maxi(0,int(value[0])-int(before[0]))
		timings[key] = {"total_us":total,"count":maxi(0,int(value[1])-int(before[1])),"cumulative_max_us":int(value[2]),"window_max_us":int(value[3]) if value.size()>3 else null,"ms_per_frame":total/1000.0/maxi(1,frames)}
		if key!="resource_wait": measured_us += total
	timings["engine_gpu_wait"] = {"total_us":maxi(0,elapsed_us-measured_us),"ms_per_frame":maxi(0,elapsed_us-measured_us)/1000.0/maxi(1,frames),"kind":"unseparated_residual"}
	var details := {}
	for key in current.get("detail_timings",{}):
		var value: Array = current.detail_timings[key]
		var before: Array = baseline.get("detail_timings",{}).get(key,[0,0,0])
		var total := maxi(0,int(value[0])-int(before[0]))
		var count := maxi(0,int(value[1])-int(before[1]))
		if count>0:
			details[key] = {"total_us":total,"count":count,"ms_per_frame":total/1000.0/maxi(1,frames),"ms_per_call":total/1000.0/count,"window_max_ms":value[3]/1000.0 if value.size()>3 else null,"cumulative_max_ms":value[2]/1000.0}
	var render_rows := {}
	for key in current.get("render_rows",{}):
		var value: Array = current.render_rows[key]
		var before: Array = baseline.get("render_rows",{}).get(key,[0,0,0])
		render_rows[key] = maxf(0.0,float(value[0])-float(before[0]))/maxi(1,int(value[1])-int(before[1]))
	return {"timings":timings,"detail_timings":details,"render_rows":render_rows,"frames":frames,"elapsed_us":elapsed_us,"packed_bytes_per_frame":maxi(0,int(current.get("packed_bytes",0))-int(baseline.get("packed_bytes",0)))/float(maxi(1,frames)),"packed_bytes_kind":"logical_payload"}
