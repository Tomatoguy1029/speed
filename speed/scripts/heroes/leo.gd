extends HeroBehavior

func trace_width() -> float:
	return float(def.params.get("width_mult", 1.0)) if active() else 1.0
