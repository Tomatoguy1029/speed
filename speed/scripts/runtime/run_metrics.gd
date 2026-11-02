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
		timings[key] = {"total_us":total,"count":maxi(0,int(value[1])-int(before[1])),"cumulative_max_us":int(value[2]),"ms_per_frame":total/1000.0/maxi(1,frames)}
		if key!="resource_wait": measured_us += total
	timings["engine_gpu_wait"] = {"total_us":maxi(0,elapsed_us-measured_us),"ms_per_frame":maxi(0,elapsed_us-measured_us)/1000.0/maxi(1,frames),"kind":"unseparated_residual"}
	return {"timings":timings,"frames":frames,"elapsed_us":elapsed_us,"packed_bytes_per_frame":maxi(0,int(current.get("packed_bytes",0))-int(baseline.get("packed_bytes",0)))/float(maxi(1,frames)),"packed_bytes_kind":"logical_payload"}
