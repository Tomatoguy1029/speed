## C++確認で共有する機体・描線の設定項目。
extends RefCounted
const CONFIG_KEYS := ["start_radius", "base_max_speed", "stick_dead_zone", "mouse_dead_zone", "steer_cruise", "glide_hold", "glide_fade", "cruise_floor", "energy_cut", "cruise_drag", "overcap_decay", "field_radius", "boundary_push", "ship_radius", "crash_restitution", "ship_hurt_time"]
const STAT_KEYS := ["max_hp", "max_speed", "turn_rate", "acceleration", "glide_duration_mult", "invulnerability"]
const STATE_KEYS := ["ship_pos", "ship_vel", "ship_heading", "ship_hp", "ship_hurt", "ship_invuln", "ship_shield_flash", "ship_shield_t", "ship_shield_max", "ship_boost_t", "ship_fade_t", "glide", "glide_t", "glide_speed", "peak_speed"]
const DRAW_CONFIG := ["draw_min_charge", "draw_length", "draw_step", "draw_confirm_delay", "draw_run_time", "draw_time_scale", "draw_run_slow_ref", "draw_run_scale_min", "boost_duration", "carry", "launch_ratio", "glide_speed_ratio"]
const DRAW_STATS := ["capacity", "charge_time", "length_mult"]
const DRAW_STATE := ["gauge", "drawing", "draw_started", "draw_blocked", "trace_full_charge", "draw_start_charge", "draw_gauge", "draw_limit", "draw_length", "draw_points", "tracing", "dash_id", "trace_path", "trace_lengths", "trace_total", "trace_progress"]
