// 共通スキーマから生成。直接編集しない。
#pragma once
#include "../binary_reader.h"
#include <vector>
#include <unordered_set>
#include "../../state/run_state.h"
namespace speed {
struct RunConfig {
    uint32_t id{};
    double aim_lag{};
    double aim_speed{};
    double crystal_low{};
    double crystal_mid{};
    double crystal_high{};
    double ship_config_start_radius{};
    double ship_config_base_max_speed{};
    double ship_config_stick_dead_zone{};
    double ship_config_mouse_dead_zone{};
    double ship_config_steer_cruise{};
    double ship_config_glide_hold{};
    double ship_config_glide_fade{};
    double ship_config_cruise_floor{};
    double ship_config_energy_cut{};
    double ship_config_cruise_drag{};
    double ship_config_overcap_decay{};
    double ship_config_field_radius{};
    double ship_config_boundary_push{};
    double ship_config_ship_radius{};
    double ship_config_crash_restitution{};
    double ship_config_ship_hurt_time{};
    double ship_config_max_hp{};
    double ship_config_max_speed{};
    double ship_config_turn_rate{};
    double ship_config_acceleration{};
    double ship_config_glide_duration_mult{};
    double ship_config_invulnerability{};
    double draw_config_min_charge{};
    double draw_config_length{};
    double draw_config_point_step{};
    double draw_config_confirm_delay{};
    double draw_config_run_time{};
    double draw_config_time_scale{};
    double draw_config_slow_ref{};
    double draw_config_scale_min{};
    double draw_config_boost_duration{};
    double draw_config_carry{};
    double draw_config_launch_ratio{};
    double draw_config_glide_ratio{};
    double draw_config_capacity{};
    double draw_config_charge_time{};
    double draw_config_length_mult{};
    double camera_base_view{};
    double camera_zoom_ref_speed{};
    double camera_zoom_exp{};
    double camera_zoom_min{};
    double camera_look_ahead{};
    uint32_t world_tick_div{};
    double grid_cell{};
    double time_limit{};
    double combat_base_attack{};
    double combat_atk_scale{};
    double combat_ram_speed_ratio{};
    double combat_crit_armor{};
    double combat_touch_damage{};
    double combat_contact_cooldown{};
    double combat_bounce_keep{};
    double combat_bounce_min_speed{};
    double combat_kill_hitstop{};
    double combat_kill_hitstop_cap{};
    double combat_kill_hitstop_regen{};
    double combat_hitstop_big_mult{};
    double combat_hitstop_crit_mult{};
    double combat_max_enemy_radius{};
    double combat_attack_mult{};
    double combat_crit_chance{};
    double combat_crit_mult{};
    bool combat_ready{};
    bool pickups_ready{};
    int64_t gem_max{};
    double strong_gold_chance{};
    double coin_radius{};
    double pickup_xp_mult{};
    double pickup_speed_mult{};
    double pickup_xp_radius{};
    bool fixed_rewards{};
    double character_scale{};
    bool projectiles_ready{};
    double debris_life{};
    double debris_knock{};
    int64_t trail_points{};
    uint32_t ship_visual{};
    uint32_t shot_visual{};
    uint32_t crystal_visual{};
    uint32_t coin_visual{};
    uint32_t cannon_visual{};
    double enemy_face_move{};
    double pickup_repair_fraction{};
    double pickup_life{};
    double trace_radius{};
};
inline bool read(BinaryReader &input, RunConfig &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.aim_lag)) return false;
    if (out.aim_lag < 0) return false;
    if (!input.read_f64(out.aim_speed)) return false;
    if (out.aim_speed < 0) return false;
    if (!input.read_f64(out.crystal_low)) return false;
    if (out.crystal_low < 0) return false;
    if (!input.read_f64(out.crystal_mid)) return false;
    if (out.crystal_mid < 0) return false;
    if (!input.read_f64(out.crystal_high)) return false;
    if (out.crystal_high < 0) return false;
    if (!input.read_f64(out.ship_config_start_radius)) return false;
    if (out.ship_config_start_radius < 0) return false;
    if (!input.read_f64(out.ship_config_base_max_speed)) return false;
    if (out.ship_config_base_max_speed < 0) return false;
    if (!input.read_f64(out.ship_config_stick_dead_zone)) return false;
    if (out.ship_config_stick_dead_zone < 0) return false;
    if (!input.read_f64(out.ship_config_mouse_dead_zone)) return false;
    if (out.ship_config_mouse_dead_zone < 0) return false;
    if (!input.read_f64(out.ship_config_steer_cruise)) return false;
    if (out.ship_config_steer_cruise < 0) return false;
    if (!input.read_f64(out.ship_config_glide_hold)) return false;
    if (out.ship_config_glide_hold < 0) return false;
    if (!input.read_f64(out.ship_config_glide_fade)) return false;
    if (out.ship_config_glide_fade < 0) return false;
    if (!input.read_f64(out.ship_config_cruise_floor)) return false;
    if (out.ship_config_cruise_floor < 0) return false;
    if (!input.read_f64(out.ship_config_energy_cut)) return false;
    if (out.ship_config_energy_cut < 0) return false;
    if (!input.read_f64(out.ship_config_cruise_drag)) return false;
    if (out.ship_config_cruise_drag < 0) return false;
    if (!input.read_f64(out.ship_config_overcap_decay)) return false;
    if (out.ship_config_overcap_decay < 0) return false;
    if (!input.read_f64(out.ship_config_field_radius)) return false;
    if (out.ship_config_field_radius < 0) return false;
    if (!input.read_f64(out.ship_config_boundary_push)) return false;
    if (out.ship_config_boundary_push < 0) return false;
    if (!input.read_f64(out.ship_config_ship_radius)) return false;
    if (out.ship_config_ship_radius < 0) return false;
    if (!input.read_f64(out.ship_config_crash_restitution)) return false;
    if (out.ship_config_crash_restitution < 0) return false;
    if (!input.read_f64(out.ship_config_ship_hurt_time)) return false;
    if (out.ship_config_ship_hurt_time < 0) return false;
    if (!input.read_f64(out.ship_config_max_hp)) return false;
    if (out.ship_config_max_hp < 0) return false;
    if (!input.read_f64(out.ship_config_max_speed)) return false;
    if (out.ship_config_max_speed < 0) return false;
    if (!input.read_f64(out.ship_config_turn_rate)) return false;
    if (out.ship_config_turn_rate < 0) return false;
    if (!input.read_f64(out.ship_config_acceleration)) return false;
    if (out.ship_config_acceleration < 0) return false;
    if (!input.read_f64(out.ship_config_glide_duration_mult)) return false;
    if (out.ship_config_glide_duration_mult < 0) return false;
    if (!input.read_f64(out.ship_config_invulnerability)) return false;
    if (out.ship_config_invulnerability < 0) return false;
    if (!input.read_f64(out.draw_config_min_charge)) return false;
    if (out.draw_config_min_charge < 0) return false;
    if (!input.read_f64(out.draw_config_length)) return false;
    if (out.draw_config_length < 0) return false;
    if (!input.read_f64(out.draw_config_point_step)) return false;
    if (out.draw_config_point_step < 0) return false;
    if (!input.read_f64(out.draw_config_confirm_delay)) return false;
    if (out.draw_config_confirm_delay < 0) return false;
    if (!input.read_f64(out.draw_config_run_time)) return false;
    if (out.draw_config_run_time < 0) return false;
    if (!input.read_f64(out.draw_config_time_scale)) return false;
    if (out.draw_config_time_scale < 0) return false;
    if (!input.read_f64(out.draw_config_slow_ref)) return false;
    if (out.draw_config_slow_ref < 0) return false;
    if (!input.read_f64(out.draw_config_scale_min)) return false;
    if (out.draw_config_scale_min < 0) return false;
    if (!input.read_f64(out.draw_config_boost_duration)) return false;
    if (out.draw_config_boost_duration < 0) return false;
    if (!input.read_f64(out.draw_config_carry)) return false;
    if (out.draw_config_carry < 0) return false;
    if (!input.read_f64(out.draw_config_launch_ratio)) return false;
    if (out.draw_config_launch_ratio < 0) return false;
    if (!input.read_f64(out.draw_config_glide_ratio)) return false;
    if (out.draw_config_glide_ratio < 0) return false;
    if (!input.read_f64(out.draw_config_capacity)) return false;
    if (out.draw_config_capacity < 0) return false;
    if (!input.read_f64(out.draw_config_charge_time)) return false;
    if (out.draw_config_charge_time < 0) return false;
    if (!input.read_f64(out.draw_config_length_mult)) return false;
    if (out.draw_config_length_mult < 0) return false;
    if (!input.read_f64(out.camera_base_view)) return false;
    if (out.camera_base_view < 0) return false;
    if (!input.read_f64(out.camera_zoom_ref_speed)) return false;
    if (out.camera_zoom_ref_speed < 0) return false;
    if (!input.read_f64(out.camera_zoom_exp)) return false;
    if (out.camera_zoom_exp < 0) return false;
    if (!input.read_f64(out.camera_zoom_min)) return false;
    if (out.camera_zoom_min < 0) return false;
    if (!input.read_f64(out.camera_look_ahead)) return false;
    if (out.camera_look_ahead < 0) return false;
    if (!input.read_u32(out.world_tick_div)) return false;
    if (out.world_tick_div < 1) return false;
    if (!input.read_f64(out.grid_cell)) return false;
    if (out.grid_cell < 0) return false;
    if (!input.read_f64(out.time_limit)) return false;
    if (!input.read_f64(out.combat_base_attack)) return false;
    if (out.combat_base_attack < 0) return false;
    if (!input.read_f64(out.combat_atk_scale)) return false;
    if (out.combat_atk_scale < 0) return false;
    if (!input.read_f64(out.combat_ram_speed_ratio)) return false;
    if (out.combat_ram_speed_ratio < 0) return false;
    if (!input.read_f64(out.combat_crit_armor)) return false;
    if (out.combat_crit_armor < 0) return false;
    if (!input.read_f64(out.combat_touch_damage)) return false;
    if (out.combat_touch_damage < 0) return false;
    if (!input.read_f64(out.combat_contact_cooldown)) return false;
    if (out.combat_contact_cooldown < 0) return false;
    if (!input.read_f64(out.combat_bounce_keep)) return false;
    if (out.combat_bounce_keep < 0) return false;
    if (!input.read_f64(out.combat_bounce_min_speed)) return false;
    if (out.combat_bounce_min_speed < 0) return false;
    if (!input.read_f64(out.combat_kill_hitstop)) return false;
    if (out.combat_kill_hitstop < 0) return false;
    if (!input.read_f64(out.combat_kill_hitstop_cap)) return false;
    if (out.combat_kill_hitstop_cap < 0) return false;
    if (!input.read_f64(out.combat_kill_hitstop_regen)) return false;
    if (out.combat_kill_hitstop_regen < 0) return false;
    if (!input.read_f64(out.combat_hitstop_big_mult)) return false;
    if (out.combat_hitstop_big_mult < 0) return false;
    if (!input.read_f64(out.combat_hitstop_crit_mult)) return false;
    if (out.combat_hitstop_crit_mult < 0) return false;
    if (!input.read_f64(out.combat_max_enemy_radius)) return false;
    if (out.combat_max_enemy_radius < 0) return false;
    if (!input.read_f64(out.combat_attack_mult)) return false;
    if (out.combat_attack_mult < 0) return false;
    if (!input.read_f64(out.combat_crit_chance)) return false;
    if (out.combat_crit_chance < 0) return false;
    if (!input.read_f64(out.combat_crit_mult)) return false;
    if (out.combat_crit_mult < 0) return false;
    if (!input.read_bool(out.combat_ready)) return false;
    if (!input.read_bool(out.pickups_ready)) return false;
    if (!input.read_i64(out.gem_max)) return false;
    if (out.gem_max < 1) return false;
    if (!input.read_f64(out.strong_gold_chance)) return false;
    if (out.strong_gold_chance < 0) return false;
    if (!input.read_f64(out.coin_radius)) return false;
    if (out.coin_radius < 0) return false;
    if (!input.read_f64(out.pickup_xp_mult)) return false;
    if (out.pickup_xp_mult < 0) return false;
    if (!input.read_f64(out.pickup_speed_mult)) return false;
    if (out.pickup_speed_mult < 0) return false;
    if (!input.read_f64(out.pickup_xp_radius)) return false;
    if (out.pickup_xp_radius < 0) return false;
    if (!input.read_bool(out.fixed_rewards)) return false;
    if (!input.read_f64(out.character_scale)) return false;
    if (out.character_scale < 0) return false;
    if (!input.read_bool(out.projectiles_ready)) return false;
    if (!input.read_f64(out.debris_life)) return false;
    if (out.debris_life < 0) return false;
    if (!input.read_f64(out.debris_knock)) return false;
    if (out.debris_knock < 0) return false;
    if (!input.read_i64(out.trail_points)) return false;
    if (out.trail_points < 0) return false;
    if (!input.read_u32(out.ship_visual)) return false;
    if (!input.read_u32(out.shot_visual)) return false;
    if (!input.read_u32(out.crystal_visual)) return false;
    if (!input.read_u32(out.coin_visual)) return false;
    if (!input.read_u32(out.cannon_visual)) return false;
    if (!input.read_f64(out.enemy_face_move)) return false;
    if (out.enemy_face_move < 0) return false;
    if (!input.read_f64(out.pickup_repair_fraction)) return false;
    if (out.pickup_repair_fraction < 0) return false;
    if (out.pickup_repair_fraction > 1) return false;
    if (!input.read_f64(out.pickup_life)) return false;
    if (out.pickup_life < 0) return false;
    if (!input.read_f64(out.trace_radius)) return false;
    if (out.trace_radius < 0) return false;
    return true;
}
struct StringEntry {
    uint32_t id{};
    std::string value{};
};
inline bool read(BinaryReader &input, StringEntry &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_string(out.value)) return false;
    return true;
}
struct DefinitionIndex {
    uint32_t id{};
    uint32_t enemy{};
};
inline bool read(BinaryReader &input, DefinitionIndex &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    return true;
}
struct EnemyRecord {
    uint32_t id{};
    double hp{};
    double armor{};
    double radius{};
    double speed{};
    double fire_interval{};
    double xp{};
    double knockback{};
    double hitstop_multiplier{};
    double attack_value{};
    double attack_priority{};
    double attack_weight{};
    double warn{};
    bool attack_managed{};
    int64_t rank{};
    bool size_var{};
    float color_r{};
    float color_g{};
    float color_b{};
    float color_a{};
    double scaling_radius{};
    double scaling_hp{};
    double scaling_armor{};
    double scaling_hp_mult{};
    double scaling_armor_mult{};
    double scaling_character{};
    double scaling_visual{};
    double scaling_collision{};
    bool fixed_sprite{};
    uint32_t reward_low{};
    uint32_t reward_mid{};
    uint32_t reward_high{};
    bool gold_eligible{};
    uint32_t visual_id{};
    double sprite_scale{};
    double sprite_angle{};
    uint32_t kind{};
    double turn{};
    bool reward_scattered{};
    bool reward_burst{};
    uint32_t gate{};
    double gate_arc{};
};
inline bool read(BinaryReader &input, EnemyRecord &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.hp)) return false;
    if (out.hp < 0) return false;
    if (!input.read_f64(out.armor)) return false;
    if (out.armor < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.fire_interval)) return false;
    if (out.fire_interval < 0) return false;
    if (!input.read_f64(out.xp)) return false;
    if (out.xp < 0) return false;
    if (!input.read_f64(out.knockback)) return false;
    if (out.knockback < 0) return false;
    if (!input.read_f64(out.hitstop_multiplier)) return false;
    if (out.hitstop_multiplier < 0) return false;
    if (!input.read_f64(out.attack_value)) return false;
    if (out.attack_value < 0) return false;
    if (!input.read_f64(out.attack_priority)) return false;
    if (!input.read_f64(out.attack_weight)) return false;
    if (out.attack_weight < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_bool(out.attack_managed)) return false;
    if (!input.read_i64(out.rank)) return false;
    if (out.rank < 0) return false;
    if (!input.read_bool(out.size_var)) return false;
    if (!input.read_f32(out.color_r)) return false;
    if (!input.read_f32(out.color_g)) return false;
    if (!input.read_f32(out.color_b)) return false;
    if (!input.read_f32(out.color_a)) return false;
    if (!input.read_f64(out.scaling_radius)) return false;
    if (out.scaling_radius < 0) return false;
    if (!input.read_f64(out.scaling_hp)) return false;
    if (out.scaling_hp < 0) return false;
    if (!input.read_f64(out.scaling_armor)) return false;
    if (out.scaling_armor < 0) return false;
    if (!input.read_f64(out.scaling_hp_mult)) return false;
    if (out.scaling_hp_mult < 0) return false;
    if (!input.read_f64(out.scaling_armor_mult)) return false;
    if (out.scaling_armor_mult < 0) return false;
    if (!input.read_f64(out.scaling_character)) return false;
    if (out.scaling_character < 0) return false;
    if (!input.read_f64(out.scaling_visual)) return false;
    if (out.scaling_visual < 0) return false;
    if (!input.read_f64(out.scaling_collision)) return false;
    if (out.scaling_collision < 0) return false;
    if (!input.read_bool(out.fixed_sprite)) return false;
    if (!input.read_u32(out.reward_low)) return false;
    if (!input.read_u32(out.reward_mid)) return false;
    if (!input.read_u32(out.reward_high)) return false;
    if (!input.read_bool(out.gold_eligible)) return false;
    if (!input.read_u32(out.visual_id)) return false;
    if (!input.read_f64(out.sprite_scale)) return false;
    if (out.sprite_scale < 0) return false;
    if (!input.read_f64(out.sprite_angle)) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 43) return false;
    if (!input.read_f64(out.turn)) return false;
    if (out.turn < 0) return false;
    if (!input.read_bool(out.reward_scattered)) return false;
    if (!input.read_bool(out.reward_burst)) return false;
    if (!input.read_u32(out.gate)) return false;
    if (out.gate > 7) return false;
    if (!input.read_f64(out.gate_arc)) return false;
    if (out.gate_arc < 0) return false;
    return true;
}
struct LoadoutDefinition {
    uint32_t id{};
    uint32_t kind{};
    uint32_t maximum_level{};
    std::string external_id{};
    bool comet_only{};
};
inline bool read(BinaryReader &input, LoadoutDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 1) return false;
    if (!input.read_u32(out.maximum_level)) return false;
    if (out.maximum_level < 1) return false;
    if (!input.read_string(out.external_id)) return false;
    if (!input.read_bool(out.comet_only)) return false;
    return true;
}
struct HeroDefinition {
    uint32_t id{};
    std::string external_id{};
    uint32_t stage{};
    double cooldown{};
    double duration{};
};
inline bool read(BinaryReader &input, HeroDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_string(out.external_id)) return false;
    if (!input.read_u32(out.stage)) return false;
    if (!input.read_f64(out.cooldown)) return false;
    if (out.cooldown < 0) return false;
    if (!input.read_f64(out.duration)) return false;
    if (out.duration < 0) return false;
    return true;
}
struct FieldDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, FieldDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct PopulationDefinition {
    uint32_t id{};
    bool active{};
    double density{};
    double bonus_pop{};
    double boss_start{};
    double recycle_scale{};
    double region_cap{};
    double margin{};
    double field_radius{};
    double planet_radius{};
    double total_cap{};
    double refill_time{};
};
inline bool read(BinaryReader &input, PopulationDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_bool(out.active)) return false;
    if (!input.read_f64(out.density)) return false;
    if (out.density < 0) return false;
    if (!input.read_f64(out.bonus_pop)) return false;
    if (out.bonus_pop < 0) return false;
    if (!input.read_f64(out.boss_start)) return false;
    if (out.boss_start < 0) return false;
    if (!input.read_f64(out.recycle_scale)) return false;
    if (out.recycle_scale < 0) return false;
    if (!input.read_f64(out.region_cap)) return false;
    if (out.region_cap < 0) return false;
    if (!input.read_f64(out.margin)) return false;
    if (out.margin < 0) return false;
    if (!input.read_f64(out.field_radius)) return false;
    if (out.field_radius < 0) return false;
    if (!input.read_f64(out.planet_radius)) return false;
    if (out.planet_radius < 0) return false;
    if (!input.read_f64(out.total_cap)) return false;
    if (out.total_cap < 0) return false;
    if (!input.read_f64(out.refill_time)) return false;
    if (out.refill_time < 0) return false;
    return true;
}
struct FormationDefinition {
    uint32_t id{};
    double base_view{};
};
inline bool read(BinaryReader &input, FormationDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.base_view)) return false;
    if (out.base_view < 0) return false;
    return true;
}
struct BossFlowDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, BossFlowDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct TechniqueDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, TechniqueDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct ResourceKey {
    uint32_t id{};
    uint32_t role{};
};
inline bool read(BinaryReader &input, ResourceKey &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.role)) return false;
    if (out.role > 16) return false;
    return true;
}
struct ForwardDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double interval{};
    double damage{};
    double life{};
    double spread{};
    double knock{};
    uint32_t pierce{};
};
inline bool read(BinaryReader &input, ForwardDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_u32(out.pierce)) return false;
    return true;
}
struct BiteDefinition {
    uint32_t id{};
    double reach{};
    double warn{};
    double rest{};
    double radius{};
    double damage{};
    double duration{};
    uint32_t visual_key{};
    bool hit{};
    bool fade{};
};
inline bool read(BinaryReader &input, BiteDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.reach)) return false;
    if (out.reach < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.rest)) return false;
    if (out.rest < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.duration)) return false;
    if (out.duration < 0) return false;
    if (!input.read_u32(out.visual_key)) return false;
    if (out.visual_key < 1) return false;
    if (!input.read_bool(out.hit)) return false;
    if (!input.read_bool(out.fade)) return false;
    return true;
}
struct LifecycleDefinition {
    uint32_t id{};
    double death_freeze_time{};
    double death_explosion_time{};
    double death_game_over_time{};
    uint32_t clear_bonus{};
    std::string legendary{};
    double death_world_dim{};
};
inline bool read(BinaryReader &input, LifecycleDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.death_freeze_time)) return false;
    if (out.death_freeze_time < 0) return false;
    if (!input.read_f64(out.death_explosion_time)) return false;
    if (out.death_explosion_time < 0) return false;
    if (!input.read_f64(out.death_game_over_time)) return false;
    if (out.death_game_over_time < 0) return false;
    if (!input.read_u32(out.clear_bonus)) return false;
    if (out.clear_bonus < 0) return false;
    if (!input.read_string(out.legendary)) return false;
    if (!input.read_f64(out.death_world_dim)) return false;
    if (out.death_world_dim < 0) return false;
    if (out.death_world_dim > 1) return false;
    return true;
}
struct EnemyTuningValue {
    uint32_t id{};
    uint32_t enemy{};
    std::string key{};
    double value{};
};
inline bool read(BinaryReader &input, EnemyTuningValue &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    if (!input.read_string(out.key)) return false;
    if (!input.read_f64(out.value)) return false;
    return true;
}
struct ContactDefinition {
    uint32_t id{};
    uint32_t shape{};
    uint32_t scale{};
    uint32_t hit_policy{};
    bool add_ship_radius{};
    bool ship_sweep{};
    double half_width{};
};
inline bool read(BinaryReader &input, ContactDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.shape)) return false;
    if (out.shape > 7) return false;
    if (!input.read_u32(out.scale)) return false;
    if (out.scale > 1) return false;
    if (!input.read_u32(out.hit_policy)) return false;
    if (out.hit_policy > 3) return false;
    if (!input.read_bool(out.add_ship_radius)) return false;
    if (!input.read_bool(out.ship_sweep)) return false;
    if (!input.read_f64(out.half_width)) return false;
    if (out.half_width < 0) return false;
    return true;
}
struct HostileDefinition {
    uint32_t id{};
    uint32_t kind{};
    double radius{};
    double life{};
    double damage{};
    double slow{};
    double turn{};
    uint32_t visual{};
    uint32_t stone_visual{};
    uint32_t contact{};
};
inline bool read(BinaryReader &input, HostileDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 2) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.slow)) return false;
    if (out.slow < 0) return false;
    if (!input.read_f64(out.turn)) return false;
    if (out.turn < 0) return false;
    if (!input.read_u32(out.visual)) return false;
    if (out.visual < 1) return false;
    if (!input.read_u32(out.stone_visual)) return false;
    if (out.stone_visual < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    return true;
}
struct BeamDefinition {
    uint32_t id{};
    uint32_t contact{};
};
inline bool read(BinaryReader &input, BeamDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    return true;
}
struct FriendShotDefinition {
    uint32_t id{};
    uint32_t contact{};
};
inline bool read(BinaryReader &input, FriendShotDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    return true;
}
struct WaveDefinition {
    uint32_t id{};
    uint32_t contact{};
    double enemy_min_distance{};
    double enemy_knock{};
};
inline bool read(BinaryReader &input, WaveDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    if (!input.read_f64(out.enemy_min_distance)) return false;
    if (out.enemy_min_distance < 0) return false;
    if (!input.read_f64(out.enemy_knock)) return false;
    if (out.enemy_knock < 0) return false;
    return true;
}
struct WallDefinition {
    uint32_t id{};
    uint32_t contact{};
};
inline bool read(BinaryReader &input, WallDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    return true;
}
struct SlashDefinition {
    uint32_t id{};
    uint32_t claw{};
    uint32_t sample{};
    float x{};
    float y{};
    double thickness{};
    uint32_t contact{};
};
inline bool read(BinaryReader &input, SlashDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.claw)) return false;
    if (out.claw > 2) return false;
    if (!input.read_u32(out.sample)) return false;
    if (out.sample > 16) return false;
    if (!input.read_f32(out.x)) return false;
    if (!input.read_f32(out.y)) return false;
    if (!input.read_f64(out.thickness)) return false;
    if (out.thickness < 0) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    return true;
}
struct BoltDefinition {
    uint32_t id{};
    double radius{};
    double life{};
    double flight_scale{};
    float tint_r{};
    float tint_g{};
    float tint_b{};
    float tint_a{};
    uint32_t contact{};
};
inline bool read(BinaryReader &input, BoltDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.flight_scale)) return false;
    if (out.flight_scale < 0) return false;
    if (!input.read_f32(out.tint_r)) return false;
    if (!input.read_f32(out.tint_g)) return false;
    if (!input.read_f32(out.tint_b)) return false;
    if (!input.read_f32(out.tint_a)) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    return true;
}
struct LightArrowDefinition {
    uint32_t id{};
    bool cosmic{};
    uint32_t contact{};
    double flight_scale{};
    double shot_length_scale{};
    double shot_width_scale{};
    double core_width{};
    double cosmic_speed{};
    uint32_t cosmic_star_count{};
    float arrow_r{};
    float arrow_g{};
    float arrow_b{};
    float arrow_a{};
    float cosmic_a_r{};
    float cosmic_a_g{};
    float cosmic_a_b{};
    float cosmic_a_a{};
    float cosmic_b_r{};
    float cosmic_b_g{};
    float cosmic_b_b{};
    float cosmic_b_a{};
    float tint_r{};
    float tint_g{};
    float tint_b{};
    float tint_a{};
};
inline bool read(BinaryReader &input, LightArrowDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_bool(out.cosmic)) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    if (!input.read_f64(out.flight_scale)) return false;
    if (out.flight_scale < 0) return false;
    if (!input.read_f64(out.shot_length_scale)) return false;
    if (out.shot_length_scale < 0) return false;
    if (!input.read_f64(out.shot_width_scale)) return false;
    if (out.shot_width_scale < 0) return false;
    if (!input.read_f64(out.core_width)) return false;
    if (out.core_width < 0) return false;
    if (!input.read_f64(out.cosmic_speed)) return false;
    if (out.cosmic_speed < 0) return false;
    if (!input.read_u32(out.cosmic_star_count)) return false;
    if (out.cosmic_star_count > 8) return false;
    if (!input.read_f32(out.arrow_r)) return false;
    if (!input.read_f32(out.arrow_g)) return false;
    if (!input.read_f32(out.arrow_b)) return false;
    if (!input.read_f32(out.arrow_a)) return false;
    if (!input.read_f32(out.cosmic_a_r)) return false;
    if (!input.read_f32(out.cosmic_a_g)) return false;
    if (!input.read_f32(out.cosmic_a_b)) return false;
    if (!input.read_f32(out.cosmic_a_a)) return false;
    if (!input.read_f32(out.cosmic_b_r)) return false;
    if (!input.read_f32(out.cosmic_b_g)) return false;
    if (!input.read_f32(out.cosmic_b_b)) return false;
    if (!input.read_f32(out.cosmic_b_a)) return false;
    if (!input.read_f32(out.tint_r)) return false;
    if (!input.read_f32(out.tint_g)) return false;
    if (!input.read_f32(out.tint_b)) return false;
    if (!input.read_f32(out.tint_a)) return false;
    return true;
}
struct StarBoltDefinition {
    uint32_t id{};
    double radius{};
    double life{};
    double flight_scale{};
    float tint_r{};
    float tint_g{};
    float tint_b{};
    float tint_a{};
    bool turn_with_velocity{};
    uint32_t visual{};
    uint32_t stone_visual{};
    uint32_t contact{};
};
inline bool read(BinaryReader &input, StarBoltDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.flight_scale)) return false;
    if (out.flight_scale < 0) return false;
    if (!input.read_f32(out.tint_r)) return false;
    if (!input.read_f32(out.tint_g)) return false;
    if (!input.read_f32(out.tint_b)) return false;
    if (!input.read_f32(out.tint_a)) return false;
    if (!input.read_bool(out.turn_with_velocity)) return false;
    if (!input.read_u32(out.visual)) return false;
    if (out.visual < 1) return false;
    if (!input.read_u32(out.stone_visual)) return false;
    if (out.stone_visual < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    return true;
}
struct RingHoldDefinition {
    uint32_t id{};
    double projectile_radius{};
    double life{};
    uint32_t projectile{};
};
inline bool read(BinaryReader &input, RingHoldDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.projectile_radius)) return false;
    if (out.projectile_radius < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_u32(out.projectile)) return false;
    if (out.projectile < 1) return false;
    return true;
}
struct LumpDefinition {
    uint32_t id{};
    double life{};
    uint32_t projectile{};
};
inline bool read(BinaryReader &input, LumpDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_u32(out.projectile)) return false;
    if (out.projectile < 1) return false;
    return true;
}
struct FriendDebrisDefinition {
    uint32_t id{};
    double life{};
    double knock{};
    double spread{};
    double character_scale{};
    double trail_life{};
    double trail_width{};
    uint32_t trail_points{};
    uint32_t maximum{};
    uint32_t contact{};
    float tint_r{};
    float tint_g{};
    float tint_b{};
    float tint_a{};
};
inline bool read(BinaryReader &input, FriendDebrisDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.character_scale)) return false;
    if (out.character_scale < 0) return false;
    if (!input.read_f64(out.trail_life)) return false;
    if (out.trail_life < 0) return false;
    if (!input.read_f64(out.trail_width)) return false;
    if (out.trail_width < 0) return false;
    if (!input.read_u32(out.trail_points)) return false;
    if (!input.read_u32(out.maximum)) return false;
    if (out.maximum < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    if (!input.read_f32(out.tint_r)) return false;
    if (!input.read_f32(out.tint_g)) return false;
    if (!input.read_f32(out.tint_b)) return false;
    if (!input.read_f32(out.tint_a)) return false;
    return true;
}
struct FriendHullDefinition {
    uint32_t id{};
    uint32_t contact{};
    double saw_knock{};
    double saw_spin{};
    float tint_r{};
    float tint_g{};
    float tint_b{};
    float tint_a{};
};
inline bool read(BinaryReader &input, FriendHullDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    if (!input.read_f64(out.saw_knock)) return false;
    if (out.saw_knock < 0) return false;
    if (!input.read_f64(out.saw_spin)) return false;
    if (!input.read_f32(out.tint_r)) return false;
    if (!input.read_f32(out.tint_g)) return false;
    if (!input.read_f32(out.tint_b)) return false;
    if (!input.read_f32(out.tint_a)) return false;
    return true;
}
struct FriendHullLook {
    uint32_t id{};
    uint32_t enemy{};
    double scale{};
    double angle{};
    bool fixed_angle{};
};
inline bool read(BinaryReader &input, FriendHullLook &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    if (!input.read_f64(out.scale)) return false;
    if (out.scale < 0) return false;
    if (!input.read_f64(out.angle)) return false;
    if (!input.read_bool(out.fixed_angle)) return false;
    return true;
}
struct FriendSawPoint {
    uint32_t id{};
    float x{};
    float y{};
};
inline bool read(BinaryReader &input, FriendSawPoint &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f32(out.x)) return false;
    if (!input.read_f32(out.y)) return false;
    return true;
}
struct ZoneDefinition {
    uint32_t id{};
    uint32_t style{};
    uint32_t contact{};
    double active{};
    bool hit{};
    bool fade{};
    float tint_r{};
    float tint_g{};
    float tint_b{};
    float tint_a{};
    double glow_opacity{};
    double ring_opacity{};
    double ring_width{};
    double arm_count{};
    double lightning_reach{};
    double lightning_width{};
    double hit_duration{};
    double fade_duration{};
};
inline bool read(BinaryReader &input, ZoneDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.style)) return false;
    if (out.style > 7) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    if (!input.read_f64(out.active)) return false;
    if (out.active < 0) return false;
    if (!input.read_bool(out.hit)) return false;
    if (!input.read_bool(out.fade)) return false;
    if (!input.read_f32(out.tint_r)) return false;
    if (!input.read_f32(out.tint_g)) return false;
    if (!input.read_f32(out.tint_b)) return false;
    if (!input.read_f32(out.tint_a)) return false;
    if (!input.read_f64(out.glow_opacity)) return false;
    if (out.glow_opacity < 0) return false;
    if (!input.read_f64(out.ring_opacity)) return false;
    if (out.ring_opacity < 0) return false;
    if (!input.read_f64(out.ring_width)) return false;
    if (out.ring_width < 0) return false;
    if (!input.read_f64(out.arm_count)) return false;
    if (out.arm_count < 0) return false;
    if (!input.read_f64(out.lightning_reach)) return false;
    if (out.lightning_reach < 0) return false;
    if (!input.read_f64(out.lightning_width)) return false;
    if (out.lightning_width < 0) return false;
    if (!input.read_f64(out.hit_duration)) return false;
    if (out.hit_duration < 0) return false;
    if (!input.read_f64(out.fade_duration)) return false;
    if (out.fade_duration < 0) return false;
    return true;
}
struct FloodDefinition {
    uint32_t id{};
    uint32_t beam{};
    double tail{};
    double collapse{};
    double margin{};
};
inline bool read(BinaryReader &input, FloodDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.beam)) return false;
    if (out.beam < 1) return false;
    if (!input.read_f64(out.tail)) return false;
    if (out.tail < 0) return false;
    if (!input.read_f64(out.collapse)) return false;
    if (out.collapse < 0) return false;
    if (!input.read_f64(out.margin)) return false;
    if (out.margin < 0) return false;
    return true;
}
struct LightLanceDefinition {
    uint32_t id{};
    double life{};
    double flight_time{};
    uint32_t maximum{};
};
inline bool read(BinaryReader &input, LightLanceDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.flight_time)) return false;
    if (out.flight_time < 0) return false;
    if (!input.read_u32(out.maximum)) return false;
    if (out.maximum < 1) return false;
    return true;
}
struct ShellDefinition {
    uint32_t id{};
    uint32_t contact{};
    double flight_scale{};
    float tint_r{};
    float tint_g{};
    float tint_b{};
    float tint_a{};
};
inline bool read(BinaryReader &input, ShellDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    if (!input.read_f64(out.flight_scale)) return false;
    if (out.flight_scale < 0) return false;
    if (!input.read_f32(out.tint_r)) return false;
    if (!input.read_f32(out.tint_g)) return false;
    if (!input.read_f32(out.tint_b)) return false;
    if (!input.read_f32(out.tint_a)) return false;
    return true;
}
struct ShellSource {
    uint32_t id{};
    uint32_t enemy{};
    double mouth_radius{};
    uint32_t store_max{};
};
inline bool read(BinaryReader &input, ShellSource &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    if (!input.read_f64(out.mouth_radius)) return false;
    if (out.mouth_radius < 0) return false;
    if (!input.read_u32(out.store_max)) return false;
    if (out.store_max < 1) return false;
    return true;
}
struct BudgetPhase {
    uint32_t id{};
    double start{};
    double budget{};
};
inline bool read(BinaryReader &input, BudgetPhase &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.start)) return false;
    if (out.start < 0) return false;
    if (!input.read_f64(out.budget)) return false;
    if (out.budget < 0) return false;
    return true;
}
struct PopulationPhase {
    uint32_t id{};
    std::string external_id{};
    double start{};
    double pop_from{};
    double pop_to{};
    double rate{};
    double xp_bonus{};
    double surge_interval{};
    double surge_pop{};
    double surge_ranged{};
    double surge_elite{};
    double wave_interval{};
    uint32_t attack_budget{};
    uint32_t wave_type{};
};
inline bool read(BinaryReader &input, PopulationPhase &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_string(out.external_id)) return false;
    if (!input.read_f64(out.start)) return false;
    if (!input.read_f64(out.pop_from)) return false;
    if (!input.read_f64(out.pop_to)) return false;
    if (!input.read_f64(out.rate)) return false;
    if (!input.read_f64(out.xp_bonus)) return false;
    if (!input.read_f64(out.surge_interval)) return false;
    if (!input.read_f64(out.surge_pop)) return false;
    if (!input.read_f64(out.surge_ranged)) return false;
    if (!input.read_f64(out.surge_elite)) return false;
    if (!input.read_f64(out.wave_interval)) return false;
    if (!input.read_u32(out.attack_budget)) return false;
    if (!input.read_u32(out.wave_type)) return false;
    return true;
}
struct PopulationMix {
    uint32_t id{};
    uint32_t phase{};
    uint32_t enemy{};
    double weight{};
};
inline bool read(BinaryReader &input, PopulationMix &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.phase)) return false;
    if (out.phase < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    if (!input.read_f64(out.weight)) return false;
    return true;
}
struct PopulationCurve {
    uint32_t id{};
    uint32_t enemy{};
};
inline bool read(BinaryReader &input, PopulationCurve &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    return true;
}
struct PopulationPoint {
    uint32_t id{};
    uint32_t curve{};
    double time{};
    double value{};
    double slope{};
};
inline bool read(BinaryReader &input, PopulationPoint &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.curve)) return false;
    if (out.curve < 1) return false;
    if (!input.read_f64(out.time)) return false;
    if (!input.read_f64(out.value)) return false;
    if (!input.read_f64(out.slope)) return false;
    return true;
}
struct PopulationWindow {
    uint32_t id{};
    double start{};
    double end{};
};
inline bool read(BinaryReader &input, PopulationWindow &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.start)) return false;
    if (!input.read_f64(out.end)) return false;
    return true;
}
struct PopulationType {
    uint32_t id{};
    uint32_t enemy{};
    double rank{};
    double maximum{};
    bool ranged{};
};
inline bool read(BinaryReader &input, PopulationType &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    if (!input.read_f64(out.rank)) return false;
    if (!input.read_f64(out.maximum)) return false;
    if (!input.read_bool(out.ranged)) return false;
    return true;
}
struct FormationEntry {
    uint32_t id{};
    uint32_t formation{};
    double weight{};
    double x{};
    double y{};
};
inline bool read(BinaryReader &input, FormationEntry &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.formation)) return false;
    if (out.formation < 1) return false;
    if (!input.read_f64(out.weight)) return false;
    if (out.weight < 0) return false;
    if (!input.read_f64(out.x)) return false;
    if (!input.read_f64(out.y)) return false;
    return true;
}
struct FormationLayout {
    uint32_t id{};
    uint32_t formation{};
    double weight{};
    double value{};
    int64_t managed{};
};
inline bool read(BinaryReader &input, FormationLayout &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.formation)) return false;
    if (out.formation < 1) return false;
    if (!input.read_f64(out.weight)) return false;
    if (out.weight < 0) return false;
    if (!input.read_f64(out.value)) return false;
    if (!input.read_i64(out.managed)) return false;
    if (out.managed < -1) return false;
    if (out.managed > 1) return false;
    return true;
}
struct FormationType {
    uint32_t id{};
    uint32_t layout{};
    uint32_t enemy{};
};
inline bool read(BinaryReader &input, FormationType &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.layout)) return false;
    if (out.layout < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    return true;
}
struct FormationMarker {
    uint32_t id{};
    uint32_t layout{};
    uint32_t entry{};
    uint32_t enemy{};
    double x{};
    double y{};
    double rotation{};
};
inline bool read(BinaryReader &input, FormationMarker &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.layout)) return false;
    if (out.layout < 1) return false;
    if (!input.read_u32(out.entry)) return false;
    if (out.entry < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    if (!input.read_f64(out.x)) return false;
    if (!input.read_f64(out.y)) return false;
    if (!input.read_f64(out.rotation)) return false;
    return true;
}
struct PopulationClip {
    uint32_t id{};
    double start{};
    double end{};
    double interval{};
    uint32_t groups{};
    double priority{};
};
inline bool read(BinaryReader &input, PopulationClip &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.start)) return false;
    if (!input.read_f64(out.end)) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_u32(out.groups)) return false;
    if (!input.read_f64(out.priority)) return false;
    return true;
}
struct PopulationClipType {
    uint32_t id{};
    uint32_t clip{};
    uint32_t enemy{};
};
inline bool read(BinaryReader &input, PopulationClipType &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.clip)) return false;
    if (out.clip < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (out.enemy < 1) return false;
    return true;
}
struct PopulationClipFormation {
    uint32_t id{};
    uint32_t clip{};
    uint32_t formation{};
};
inline bool read(BinaryReader &input, PopulationClipFormation &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.clip)) return false;
    if (out.clip < 1) return false;
    if (!input.read_u32(out.formation)) return false;
    if (out.formation < 1) return false;
    return true;
}
struct DeathChainDefinition {
    uint32_t id{};
    double power{};
    double radius{};
    double delay{};
    double damage{};
};
inline bool read(BinaryReader &input, DeathChainDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.power)) return false;
    if (out.power < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.delay)) return false;
    if (out.delay < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    return true;
}
struct EncounterDefinition {
    uint32_t id{};
    bool active{};
    double interval{};
};
inline bool read(BinaryReader &input, EncounterDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_bool(out.active)) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    return true;
}
struct EncounterPattern {
    uint32_t id{};
    uint32_t attempts{};
    uint32_t min_fodder{};
    double margin{};
    double window{};
    double draw_seconds{};
    double exit_clearance{};
    double rotation{};
    double scale_min{};
    double scale_max{};
    double min_spacing{};
};
inline bool read(BinaryReader &input, EncounterPattern &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.attempts)) return false;
    if (out.attempts < 1) return false;
    if (out.attempts > 32) return false;
    if (!input.read_u32(out.min_fodder)) return false;
    if (!input.read_f64(out.margin)) return false;
    if (!input.read_f64(out.window)) return false;
    if (!input.read_f64(out.draw_seconds)) return false;
    if (!input.read_f64(out.exit_clearance)) return false;
    if (!input.read_f64(out.rotation)) return false;
    if (!input.read_f64(out.scale_min)) return false;
    if (!input.read_f64(out.scale_max)) return false;
    if (!input.read_f64(out.min_spacing)) return false;
    return true;
}
struct EncounterPoint {
    uint32_t id{};
    uint32_t pattern{};
    double x{};
    double y{};
};
inline bool read(BinaryReader &input, EncounterPoint &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.pattern)) return false;
    if (out.pattern < 1) return false;
    if (!input.read_f64(out.x)) return false;
    if (!input.read_f64(out.y)) return false;
    return true;
}
struct EncounterRegion {
    uint32_t id{};
    uint32_t pattern{};
    uint32_t enemy{};
    double x{};
    double y{};
    double angle{};
    double jitter{};
    uint32_t min_count{};
    uint32_t max_count{};
    bool fodder{};
    bool elite{};
};
inline bool read(BinaryReader &input, EncounterRegion &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.pattern)) return false;
    if (out.pattern < 1) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (!input.read_f64(out.x)) return false;
    if (!input.read_f64(out.y)) return false;
    if (!input.read_f64(out.angle)) return false;
    if (!input.read_f64(out.jitter)) return false;
    if (!input.read_u32(out.min_count)) return false;
    if (out.min_count > 100) return false;
    if (!input.read_u32(out.max_count)) return false;
    if (out.max_count > 100) return false;
    if (!input.read_bool(out.fodder)) return false;
    if (!input.read_bool(out.elite)) return false;
    return true;
}
struct EncounterPhase {
    uint32_t id{};
    std::string name{};
};
inline bool read(BinaryReader &input, EncounterPhase &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_string(out.name)) return false;
    return true;
}
struct ProgressionDefinition {
    uint32_t id{};
    double xp_base{};
    double xp_growth{};
    double xp_curve{};
    double level_heal{};
    double owned_card_bias{};
    double levelup_bonus_chance{};
    double levelup_bonus_more{};
    double levelup_bonus_last{};
    uint32_t weapon_slots{};
    uint32_t trait_slots{};
    uint32_t reroll_count{};
    uint32_t start_weapon_choices{};
};
inline bool read(BinaryReader &input, ProgressionDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.xp_base)) return false;
    if (out.xp_base < 0) return false;
    if (!input.read_f64(out.xp_growth)) return false;
    if (out.xp_growth < 0) return false;
    if (!input.read_f64(out.xp_curve)) return false;
    if (out.xp_curve < 0) return false;
    if (!input.read_f64(out.level_heal)) return false;
    if (out.level_heal < 0) return false;
    if (!input.read_f64(out.owned_card_bias)) return false;
    if (out.owned_card_bias < 0) return false;
    if (!input.read_f64(out.levelup_bonus_chance)) return false;
    if (out.levelup_bonus_chance < 0) return false;
    if (!input.read_f64(out.levelup_bonus_more)) return false;
    if (out.levelup_bonus_more < 0) return false;
    if (!input.read_f64(out.levelup_bonus_last)) return false;
    if (out.levelup_bonus_last < 0) return false;
    if (!input.read_u32(out.weapon_slots)) return false;
    if (out.weapon_slots < 0) return false;
    if (!input.read_u32(out.trait_slots)) return false;
    if (out.trait_slots < 0) return false;
    if (!input.read_u32(out.reroll_count)) return false;
    if (out.reroll_count < 0) return false;
    if (!input.read_u32(out.start_weapon_choices)) return false;
    if (out.start_weapon_choices < 0) return false;
    return true;
}
struct LoadoutAsset {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t asset{};
};
inline bool read(BinaryReader &input, LoadoutAsset &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.asset)) return false;
    if (out.asset < 1) return false;
    return true;
}
struct PostMaxDefinition {
    uint32_t id{};
    std::string external_id{};
    double increment{};
    double minimum_ratio{};
    double minimum_time{};
    double maximum{};
};
inline bool read(BinaryReader &input, PostMaxDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_string(out.external_id)) return false;
    if (!input.read_f64(out.increment)) return false;
    if (out.increment < 0) return false;
    if (!input.read_f64(out.minimum_ratio)) return false;
    if (out.minimum_ratio < 0) return false;
    if (out.minimum_ratio > 1) return false;
    if (!input.read_f64(out.minimum_time)) return false;
    if (out.minimum_time < 0) return false;
    if (!input.read_f64(out.maximum)) return false;
    if (out.maximum < 0) return false;
    return true;
}
struct PostMaxTarget {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t effect{};
};
inline bool read(BinaryReader &input, PostMaxTarget &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.effect)) return false;
    if (out.effect < 1) return false;
    return true;
}
struct PostMaxInterval {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    std::string parameter{};
    double base{};
};
inline bool read(BinaryReader &input, PostMaxInterval &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_string(out.parameter)) return false;
    if (!input.read_f64(out.base)) return false;
    if (out.base < 0) return false;
    return true;
}
struct HoundDefinition {
    uint32_t id{};
    uint32_t count{};
    double gap{};
    double reach{};
    double alignment{};
    double cohesion{};
    double separation{};
    double accel{};
};
inline bool read(BinaryReader &input, HoundDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 1) return false;
    if (!input.read_f64(out.gap)) return false;
    if (out.gap < 0) return false;
    if (!input.read_f64(out.reach)) return false;
    if (out.reach < 0) return false;
    if (!input.read_f64(out.alignment)) return false;
    if (out.alignment < 0) return false;
    if (!input.read_f64(out.cohesion)) return false;
    if (out.cohesion < 0) return false;
    if (!input.read_f64(out.separation)) return false;
    if (out.separation < 0) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    return true;
}
struct ShieldDefinition {
    uint32_t id{};
    double accel{};
    double turn{};
    double weak_arc{};
    double front_arc{};
    double reflect_speed{};
    double reflect_interval{};
    double shield_time{};
    uint32_t reflected{};
};
inline bool read(BinaryReader &input, ShieldDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.turn)) return false;
    if (out.turn < 0) return false;
    if (!input.read_f64(out.weak_arc)) return false;
    if (out.weak_arc < 0) return false;
    if (!input.read_f64(out.front_arc)) return false;
    if (out.front_arc < 0) return false;
    if (!input.read_f64(out.reflect_speed)) return false;
    if (out.reflect_speed < 0) return false;
    if (!input.read_f64(out.reflect_interval)) return false;
    if (out.reflect_interval < 0) return false;
    if (!input.read_f64(out.shield_time)) return false;
    if (out.shield_time < 0) return false;
    if (!input.read_u32(out.reflected)) return false;
    if (out.reflected < 1) return false;
    return true;
}
struct GunnerDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double telegraph{};
    double bullet_speed{};
    double bullet_damage{};
    double slow{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, GunnerDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.telegraph)) return false;
    if (out.telegraph < 0) return false;
    if (!input.read_f64(out.bullet_speed)) return false;
    if (out.bullet_speed < 0) return false;
    if (!input.read_f64(out.bullet_damage)) return false;
    if (out.bullet_damage < 0) return false;
    if (!input.read_f64(out.slow)) return false;
    if (out.slow < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct BeamerDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double telegraph{};
    double beam_time{};
    double beam_length{};
    double damage{};
    double admission_duration{};
    double half_width{};
    bool cross{};
};
inline bool read(BinaryReader &input, BeamerDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.telegraph)) return false;
    if (out.telegraph < 0) return false;
    if (!input.read_f64(out.beam_time)) return false;
    if (out.beam_time < 0) return false;
    if (!input.read_f64(out.beam_length)) return false;
    if (out.beam_length < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    if (!input.read_f64(out.half_width)) return false;
    if (out.half_width < 0) return false;
    if (!input.read_bool(out.cross)) return false;
    return true;
}
struct MissileEnemyDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double warn{};
    double missile_speed{};
    double missile_turn{};
    double damage{};
    double slow{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, MissileEnemyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.missile_speed)) return false;
    if (out.missile_speed < 0) return false;
    if (!input.read_f64(out.missile_turn)) return false;
    if (out.missile_turn < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.slow)) return false;
    if (out.slow < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct RocketDefinition {
    uint32_t id{};
    double life{};
    double fuse{};
    double blast_radius{};
    double blast_damage{};
    double blast_duration{};
    double admission_duration{};
    uint32_t contact{};
};
inline bool read(BinaryReader &input, RocketDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.fuse)) return false;
    if (out.fuse < 0) return false;
    if (!input.read_f64(out.blast_radius)) return false;
    if (out.blast_radius < 0) return false;
    if (!input.read_f64(out.blast_damage)) return false;
    if (out.blast_damage < 0) return false;
    if (!input.read_f64(out.blast_duration)) return false;
    if (out.blast_duration < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    if (!input.read_u32(out.contact)) return false;
    if (out.contact < 1) return false;
    return true;
}
struct DriftDefinition {
    uint32_t id{};
    bool has_life{};
    double life{};
    bool ram_guard{};
};
inline bool read(BinaryReader &input, DriftDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_bool(out.has_life)) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_bool(out.ram_guard)) return false;
    return true;
}
struct PartDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, PartDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct DashDefinition {
    uint32_t id{};
    double range{};
    double warn{};
    double dash_time{};
    double dash_speed{};
    double recover{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, DashDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.range)) return false;
    if (out.range < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.dash_time)) return false;
    if (out.dash_time < 0) return false;
    if (!input.read_f64(out.dash_speed)) return false;
    if (out.dash_speed < 0) return false;
    if (!input.read_f64(out.recover)) return false;
    if (out.recover < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct BattleshipDefinition {
    uint32_t id{};
    double warn{};
    double bullet_speed{};
    double damage{};
    double slow{};
    double spread{};
    double weak_arc{};
    double admission_duration{};
    uint32_t volley{};
};
inline bool read(BinaryReader &input, BattleshipDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.bullet_speed)) return false;
    if (out.bullet_speed < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.slow)) return false;
    if (out.slow < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.weak_arc)) return false;
    if (out.weak_arc < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    if (!input.read_u32(out.volley)) return false;
    if (out.volley < 0) return false;
    return true;
}
struct SniperDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double band_len{};
    double band_width{};
    double band_narrow{};
    double track_turn{};
    double search_turn{};
    double search_sway{};
    double search_period{};
    double lock_fill{};
    double lock_decay{};
    double laser_charge{};
    double laser_delay{};
    double laser_time{};
    double laser_half_width{};
    double damage{};
    double cooldown{};
};
inline bool read(BinaryReader &input, SniperDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.band_len)) return false;
    if (out.band_len < 0) return false;
    if (!input.read_f64(out.band_width)) return false;
    if (out.band_width < 0) return false;
    if (!input.read_f64(out.band_narrow)) return false;
    if (out.band_narrow < 0) return false;
    if (!input.read_f64(out.track_turn)) return false;
    if (out.track_turn < 0) return false;
    if (!input.read_f64(out.search_turn)) return false;
    if (out.search_turn < 0) return false;
    if (!input.read_f64(out.search_sway)) return false;
    if (out.search_sway < 0) return false;
    if (!input.read_f64(out.search_period)) return false;
    if (out.search_period < 0) return false;
    if (!input.read_f64(out.lock_fill)) return false;
    if (out.lock_fill < 0) return false;
    if (!input.read_f64(out.lock_decay)) return false;
    if (out.lock_decay < 0) return false;
    if (!input.read_f64(out.laser_charge)) return false;
    if (out.laser_charge < 0) return false;
    if (!input.read_f64(out.laser_delay)) return false;
    if (out.laser_delay < 0) return false;
    if (!input.read_f64(out.laser_time)) return false;
    if (out.laser_time < 0) return false;
    if (!input.read_f64(out.laser_half_width)) return false;
    if (out.laser_half_width < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.cooldown)) return false;
    if (out.cooldown < 0) return false;
    return true;
}
struct MarlinDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double warn{};
    double dash_speed{};
    double dash_time{};
    double recover{};
};
inline bool read(BinaryReader &input, MarlinDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.dash_speed)) return false;
    if (out.dash_speed < 0) return false;
    if (!input.read_f64(out.dash_time)) return false;
    if (out.dash_time < 0) return false;
    if (!input.read_f64(out.recover)) return false;
    if (out.recover < 0) return false;
    return true;
}
struct PulserDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double warn{};
    double arc{};
    double radius{};
    double speed{};
    double width{};
    double damage{};
};
inline bool read(BinaryReader &input, PulserDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.arc)) return false;
    if (out.arc < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    return true;
}
struct DolphinDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double warn{};
    double aim_turn{};
    double arc{};
    double radius{};
    double speed{};
    double width{};
    double damage{};
    double enemy_damage{};
};
inline bool read(BinaryReader &input, DolphinDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.aim_turn)) return false;
    if (out.aim_turn < 0) return false;
    if (!input.read_f64(out.arc)) return false;
    if (out.arc < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.enemy_damage)) return false;
    if (out.enemy_damage < 0) return false;
    return true;
}
struct LynxDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double warn{};
    double slash_speed{};
    double slash_size{};
    double slash_range{};
    double damage{};
};
inline bool read(BinaryReader &input, LynxDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.slash_speed)) return false;
    if (out.slash_speed < 0) return false;
    if (!input.read_f64(out.slash_size)) return false;
    if (out.slash_size < 0) return false;
    if (!input.read_f64(out.slash_range)) return false;
    if (out.slash_range < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    return true;
}
struct SoldierDefinition {
    uint32_t id{};
    double accel{};
    double bolt_speed{};
    double damage{};
    double mutiny_shot{};
};
inline bool read(BinaryReader &input, SoldierDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.bolt_speed)) return false;
    if (out.bolt_speed < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.mutiny_shot)) return false;
    if (out.mutiny_shot < 0) return false;
    return true;
}
struct AurigaDefinition {
    uint32_t id{};
    double accel{};
    double trail_step{};
    double trail_time{};
    double trail_width{};
    double wheel_gap{};
    double damage{};
};
inline bool read(BinaryReader &input, AurigaDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.trail_step)) return false;
    if (out.trail_step < 0) return false;
    if (!input.read_f64(out.trail_time)) return false;
    if (out.trail_time < 0) return false;
    if (!input.read_f64(out.trail_width)) return false;
    if (out.trail_width < 0) return false;
    if (!input.read_f64(out.wheel_gap)) return false;
    if (out.wheel_gap < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    return true;
}
struct ClockDefinition {
    uint32_t id{};
    double accel{};
    double warn{};
    double hand_long{};
    double hand_short{};
    double hand_width{};
    double long_speed{};
    double short_speed{};
    double damage{};
};
inline bool read(BinaryReader &input, ClockDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.hand_long)) return false;
    if (out.hand_long < 0) return false;
    if (!input.read_f64(out.hand_short)) return false;
    if (out.hand_short < 0) return false;
    if (!input.read_f64(out.hand_width)) return false;
    if (out.hand_width < 0) return false;
    if (!input.read_f64(out.long_speed)) return false;
    if (!input.read_f64(out.short_speed)) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    return true;
}
struct ReticleDefinition {
    uint32_t id{};
    double accel{};
    double aim_time{};
    double break_interval{};
    double exit_margin{};
    double follow_gap{};
    double follow_reach{};
    double retreat_speed{};
    double small_r{};
};
inline bool read(BinaryReader &input, ReticleDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.aim_time)) return false;
    if (out.aim_time < 0) return false;
    if (!input.read_f64(out.break_interval)) return false;
    if (out.break_interval < 0) return false;
    if (!input.read_f64(out.exit_margin)) return false;
    if (out.exit_margin < 0) return false;
    if (!input.read_f64(out.follow_gap)) return false;
    if (out.follow_gap < 0) return false;
    if (!input.read_f64(out.follow_reach)) return false;
    if (out.follow_reach < 0) return false;
    if (!input.read_f64(out.retreat_speed)) return false;
    if (out.retreat_speed < 0) return false;
    if (!input.read_f64(out.small_r)) return false;
    if (out.small_r < 0) return false;
    return true;
}
struct AquariusDefinition {
    uint32_t id{};
    double accel{};
    double approach{};
    double telegraph{};
    double beam_time{};
    double beam_length{};
    double spread{};
    double rest{};
    double damage{};
    double admission_duration{};
    double half_width{};
    uint32_t beams{};
};
inline bool read(BinaryReader &input, AquariusDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.approach)) return false;
    if (out.approach < 0) return false;
    if (!input.read_f64(out.telegraph)) return false;
    if (out.telegraph < 0) return false;
    if (!input.read_f64(out.beam_time)) return false;
    if (out.beam_time < 0) return false;
    if (!input.read_f64(out.beam_length)) return false;
    if (out.beam_length < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.rest)) return false;
    if (out.rest < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    if (!input.read_f64(out.half_width)) return false;
    if (out.half_width < 0) return false;
    if (!input.read_u32(out.beams)) return false;
    if (out.beams < 1) return false;
    return true;
}
struct CrossEnemyDefinition {
    uint32_t id{};
    double accel{};
    double stand_off{};
    double align_tol{};
    double beam_length{};
    double beam_time{};
    double telegraph{};
    double rest{};
    double damage{};
    double admission_duration{};
    double half_width{};
};
inline bool read(BinaryReader &input, CrossEnemyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.stand_off)) return false;
    if (out.stand_off < 0) return false;
    if (!input.read_f64(out.align_tol)) return false;
    if (out.align_tol < 0) return false;
    if (!input.read_f64(out.beam_length)) return false;
    if (out.beam_length < 0) return false;
    if (!input.read_f64(out.beam_time)) return false;
    if (out.beam_time < 0) return false;
    if (!input.read_f64(out.telegraph)) return false;
    if (out.telegraph < 0) return false;
    if (!input.read_f64(out.rest)) return false;
    if (out.rest < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    if (!input.read_f64(out.half_width)) return false;
    if (out.half_width < 0) return false;
    return true;
}
struct BomberDefinition {
    uint32_t id{};
    double accel{};
    double trigger{};
    double rush{};
    double blast_delay{};
    double blast_radius{};
    double blast_damage{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, BomberDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.trigger)) return false;
    if (out.trigger < 0) return false;
    if (!input.read_f64(out.rush)) return false;
    if (out.rush < 0) return false;
    if (!input.read_f64(out.blast_delay)) return false;
    if (out.blast_delay < 0) return false;
    if (!input.read_f64(out.blast_radius)) return false;
    if (out.blast_radius < 0) return false;
    if (!input.read_f64(out.blast_damage)) return false;
    if (out.blast_damage < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct PhoenixDefinition {
    uint32_t id{};
    double retreat_distance{};
    double retreat_time{};
    double telegraph{};
    double dive_time{};
    double impact_radius{};
    double impact_time{};
    double impact_damage{};
    double recover_time{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, PhoenixDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.retreat_distance)) return false;
    if (out.retreat_distance < 0) return false;
    if (!input.read_f64(out.retreat_time)) return false;
    if (out.retreat_time < 0) return false;
    if (!input.read_f64(out.telegraph)) return false;
    if (out.telegraph < 0) return false;
    if (!input.read_f64(out.dive_time)) return false;
    if (out.dive_time < 0) return false;
    if (!input.read_f64(out.impact_radius)) return false;
    if (out.impact_radius < 0) return false;
    if (!input.read_f64(out.impact_time)) return false;
    if (out.impact_time < 0) return false;
    if (!input.read_f64(out.impact_damage)) return false;
    if (out.impact_damage < 0) return false;
    if (!input.read_f64(out.recover_time)) return false;
    if (out.recover_time < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct AquilaDefinition {
    uint32_t id{};
    double keep{};
    double aim_time{};
    double lock_time{};
    double dash_speed{};
    double dash_time{};
    double drop_step{};
    double blast_radius{};
    double blast_delay{};
    double damage{};
    double recover{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, AquilaDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.aim_time)) return false;
    if (out.aim_time < 0) return false;
    if (!input.read_f64(out.lock_time)) return false;
    if (out.lock_time < 1e-06) return false;
    if (!input.read_f64(out.dash_speed)) return false;
    if (out.dash_speed < 1e-06) return false;
    if (!input.read_f64(out.dash_time)) return false;
    if (out.dash_time < 0) return false;
    if (!input.read_f64(out.drop_step)) return false;
    if (out.drop_step < 1e-06) return false;
    if (!input.read_f64(out.blast_radius)) return false;
    if (out.blast_radius < 0) return false;
    if (!input.read_f64(out.blast_delay)) return false;
    if (out.blast_delay < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.recover)) return false;
    if (out.recover < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct SplitDefinition {
    uint32_t id{};
    uint32_t child{};
    double bud_interval{};
    double split_speed{};
    double split_guard{};
    uint32_t max_buds{};
    uint32_t death_split{};
    uint32_t split_extra{};
};
inline bool read(BinaryReader &input, SplitDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.child)) return false;
    if (out.child < 1) return false;
    if (!input.read_f64(out.bud_interval)) return false;
    if (out.bud_interval < 0) return false;
    if (!input.read_f64(out.split_speed)) return false;
    if (out.split_speed < 0) return false;
    if (!input.read_f64(out.split_guard)) return false;
    if (out.split_guard < 0) return false;
    if (!input.read_u32(out.max_buds)) return false;
    if (out.max_buds < 0) return false;
    if (out.max_buds > 2147483647) return false;
    if (!input.read_u32(out.death_split)) return false;
    if (out.death_split < 0) return false;
    if (out.death_split > 2147483647) return false;
    if (!input.read_u32(out.split_extra)) return false;
    if (out.split_extra < 0) return false;
    if (out.split_extra > 2147483647) return false;
    return true;
}
struct DefenderDefinition {
    uint32_t id{};
    double accel{};
    double guard_arrive{};
    double guard_distance{};
    double guard_radius{};
    double guard_spacing{};
};
inline bool read(BinaryReader &input, DefenderDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.guard_arrive)) return false;
    if (!input.read_f64(out.guard_distance)) return false;
    if (!input.read_f64(out.guard_radius)) return false;
    if (!input.read_f64(out.guard_spacing)) return false;
    return true;
}
struct CrabDefinition {
    uint32_t id{};
    double approach{};
    double reach{};
    double telegraph{};
    double open_time{};
    double turn_angle{};
    double damage{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, CrabDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.approach)) return false;
    if (out.approach < 0) return false;
    if (!input.read_f64(out.reach)) return false;
    if (out.reach < 0) return false;
    if (!input.read_f64(out.telegraph)) return false;
    if (out.telegraph < 0) return false;
    if (!input.read_f64(out.open_time)) return false;
    if (out.open_time < 0) return false;
    if (!input.read_f64(out.turn_angle)) return false;
    if (out.turn_angle < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct CrowDefinition {
    uint32_t id{};
    uint32_t flock{};
    double aim_spread{};
    double flock_gap{};
    double gather_width{};
    double gather_behind{};
    double gather_speed{};
    double exit_margin{};
};
inline bool read(BinaryReader &input, CrowDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.flock)) return false;
    if (out.flock < 0) return false;
    if (out.flock > 2147483647) return false;
    if (!input.read_f64(out.aim_spread)) return false;
    if (!input.read_f64(out.flock_gap)) return false;
    if (!input.read_f64(out.gather_width)) return false;
    if (!input.read_f64(out.gather_behind)) return false;
    if (!input.read_f64(out.gather_speed)) return false;
    if (!input.read_f64(out.exit_margin)) return false;
    return true;
}
struct CepheusDefinition {
    uint32_t id{};
    uint32_t soldier{};
    double accel{};
    double keep{};
    double fire_interval{};
    double reinforce_interval{};
    double summon_time{};
    double mutiny_time{};
    double spacing{};
    double row_near{};
    double row_far{};
    double fan_radius{};
    double fan_step{};
};
inline bool read(BinaryReader &input, CepheusDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.soldier)) return false;
    if (out.soldier < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.fire_interval)) return false;
    if (out.fire_interval < 0) return false;
    if (!input.read_f64(out.reinforce_interval)) return false;
    if (out.reinforce_interval < 0) return false;
    if (!input.read_f64(out.summon_time)) return false;
    if (out.summon_time < 0) return false;
    if (!input.read_f64(out.mutiny_time)) return false;
    if (out.mutiny_time < 0) return false;
    if (!input.read_f64(out.spacing)) return false;
    if (out.spacing < 0) return false;
    if (!input.read_f64(out.row_near)) return false;
    if (out.row_near < 0) return false;
    if (!input.read_f64(out.row_far)) return false;
    if (out.row_far < 0) return false;
    if (!input.read_f64(out.fan_radius)) return false;
    if (out.fan_radius < 0) return false;
    if (!input.read_f64(out.fan_step)) return false;
    if (out.fan_step < 0) return false;
    return true;
}
struct PumpDefinition {
    uint32_t id{};
    uint32_t store_max{};
    uint32_t release_base{};
    double accel{};
    double pull_radius{};
    double pull{};
    double swallow_reach{};
    double swallow_interval{};
    double grow{};
    double telegraph{};
    double lock_time{};
    double shell_speed{};
    double shell_radius{};
    double shell_range{};
    double burst_radius{};
    double damage{};
    double recover{};
    double release_per{};
    double release_speed{};
    double release_damage{};
    double release_radius{};
    double mouth_radius{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, PumpDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.store_max)) return false;
    if (out.store_max < 1) return false;
    if (!input.read_u32(out.release_base)) return false;
    if (out.release_base < 0) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.pull_radius)) return false;
    if (out.pull_radius < 0) return false;
    if (!input.read_f64(out.pull)) return false;
    if (out.pull < 0) return false;
    if (!input.read_f64(out.swallow_reach)) return false;
    if (out.swallow_reach < 0) return false;
    if (!input.read_f64(out.swallow_interval)) return false;
    if (out.swallow_interval < 0) return false;
    if (!input.read_f64(out.grow)) return false;
    if (out.grow < 0) return false;
    if (!input.read_f64(out.telegraph)) return false;
    if (out.telegraph < 0) return false;
    if (!input.read_f64(out.lock_time)) return false;
    if (out.lock_time < 0) return false;
    if (!input.read_f64(out.shell_speed)) return false;
    if (out.shell_speed < 0) return false;
    if (!input.read_f64(out.shell_radius)) return false;
    if (out.shell_radius < 0) return false;
    if (!input.read_f64(out.shell_range)) return false;
    if (out.shell_range < 0) return false;
    if (!input.read_f64(out.burst_radius)) return false;
    if (out.burst_radius < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.recover)) return false;
    if (out.recover < 0) return false;
    if (!input.read_f64(out.release_per)) return false;
    if (out.release_per < 0) return false;
    if (!input.read_f64(out.release_speed)) return false;
    if (out.release_speed < 0) return false;
    if (!input.read_f64(out.release_damage)) return false;
    if (out.release_damage < 0) return false;
    if (!input.read_f64(out.release_radius)) return false;
    if (out.release_radius < 0) return false;
    if (!input.read_f64(out.mouth_radius)) return false;
    if (out.mouth_radius < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct TriangleStarDefinition {
    uint32_t id{};
};
inline bool read(BinaryReader &input, TriangleStarDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    return true;
}
struct CoronaDefinition {
    uint32_t id{};
    uint32_t capture_max{};
    double capture_interval{};
    double pull_radius{};
    double pull{};
    double ring{};
    double spin{};
    double telegraph{};
    double align_angle{};
    double throw_life{};
    double throw_speed{};
    double effect{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, CoronaDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.capture_max)) return false;
    if (out.capture_max < 1) return false;
    if (!input.read_f64(out.capture_interval)) return false;
    if (out.capture_interval < 0) return false;
    if (!input.read_f64(out.pull_radius)) return false;
    if (out.pull_radius < 0) return false;
    if (!input.read_f64(out.pull)) return false;
    if (out.pull < 0) return false;
    if (!input.read_f64(out.ring)) return false;
    if (out.ring < 0) return false;
    if (!input.read_f64(out.spin)) return false;
    if (!input.read_f64(out.telegraph)) return false;
    if (out.telegraph < 0) return false;
    if (!input.read_f64(out.align_angle)) return false;
    if (out.align_angle < 0) return false;
    if (!input.read_f64(out.throw_life)) return false;
    if (out.throw_life < 0) return false;
    if (!input.read_f64(out.throw_speed)) return false;
    if (out.throw_speed < 0) return false;
    if (!input.read_f64(out.effect)) return false;
    if (out.effect < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct CoronaType {
    uint32_t id{};
    uint32_t owner{};
    std::string name{};
    double weight{};
    double damage{};
};
inline bool read(BinaryReader &input, CoronaType &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.owner)) return false;
    if (out.owner < 1) return false;
    if (!input.read_string(out.name)) return false;
    if (!input.read_f64(out.weight)) return false;
    if (out.weight < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    return true;
}
struct RulerDefinition {
    uint32_t id{};
    double accel{};
    double keep{};
    double split_delay{};
    double half_gap{};
    double emit_back{};
    double deploy_speed{};
    double deploy_time{};
    double warn{};
    double beam_len{};
    double beam_width{};
    double beam_time{};
    double beam_start_gap{};
    double damage{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, RulerDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.keep)) return false;
    if (out.keep < 0) return false;
    if (!input.read_f64(out.split_delay)) return false;
    if (out.split_delay < 0) return false;
    if (!input.read_f64(out.half_gap)) return false;
    if (out.half_gap < 0) return false;
    if (!input.read_f64(out.emit_back)) return false;
    if (out.emit_back < 0) return false;
    if (!input.read_f64(out.deploy_speed)) return false;
    if (out.deploy_speed < 0) return false;
    if (!input.read_f64(out.deploy_time)) return false;
    if (out.deploy_time < 0) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.beam_len)) return false;
    if (out.beam_len < 0) return false;
    if (!input.read_f64(out.beam_width)) return false;
    if (out.beam_width < 0) return false;
    if (!input.read_f64(out.beam_time)) return false;
    if (out.beam_time < 0) return false;
    if (!input.read_f64(out.beam_start_gap)) return false;
    if (out.beam_start_gap < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct TriangleDefinition {
    uint32_t id{};
    uint32_t star{};
    double move_time{};
    double stop_time{};
    double span{};
    double trail_width{};
    double trail_damage{};
    double admission_duration{};
};
inline bool read(BinaryReader &input, TriangleDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.star)) return false;
    if (out.star < 1) return false;
    if (!input.read_f64(out.move_time)) return false;
    if (out.move_time < 0) return false;
    if (!input.read_f64(out.stop_time)) return false;
    if (out.stop_time < 0) return false;
    if (!input.read_f64(out.span)) return false;
    if (out.span < 0) return false;
    if (!input.read_f64(out.trail_width)) return false;
    if (out.trail_width < 0) return false;
    if (!input.read_f64(out.trail_damage)) return false;
    if (out.trail_damage < 0) return false;
    if (!input.read_f64(out.admission_duration)) return false;
    if (out.admission_duration < 0) return false;
    return true;
}
struct FieldBodyDefinition {
    uint32_t id{};
    uint32_t kind{};
    double x{};
    double y{};
    double radius{};
    uint32_t visual{};
};
inline bool read(BinaryReader &input, FieldBodyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 0) return false;
    if (!input.read_f64(out.x)) return false;
    if (!input.read_f64(out.y)) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_u32(out.visual)) return false;
    if (out.visual < 1) return false;
    return true;
}
struct MoonDefinition {
    uint32_t id{};
    uint32_t count{};
    double orbit_min{};
    double orbit_max{};
    double angle_jitter{};
    double radius_min{};
    double radius_max{};
    double angular_speed{};
    uint32_t visual{};
};
inline bool read(BinaryReader &input, MoonDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.count)) return false;
    if (!input.read_f64(out.orbit_min)) return false;
    if (out.orbit_min < 0) return false;
    if (!input.read_f64(out.orbit_max)) return false;
    if (out.orbit_max < 0) return false;
    if (!input.read_f64(out.angle_jitter)) return false;
    if (out.angle_jitter < 0) return false;
    if (!input.read_f64(out.radius_min)) return false;
    if (out.radius_min < 0) return false;
    if (!input.read_f64(out.radius_max)) return false;
    if (out.radius_max < 0) return false;
    if (!input.read_f64(out.angular_speed)) return false;
    if (!input.read_u32(out.visual)) return false;
    if (out.visual < 1) return false;
    return true;
}
struct RockFieldDefinition {
    uint32_t id{};
    uint32_t meteor_count{};
    uint32_t iron_count{};
    uint32_t saw_count{};
    double planet_radius{};
    double meteor_coin_chance{};
    double meteor_heal_chance{};
    double meteor_magnet_chance{};
    double saw_speed{};
    double saw_power{};
    double saw_life{};
    uint32_t meteor{};
    uint32_t iron{};
    uint32_t saw{};
    uint32_t meteor_visual_0{};
    uint32_t meteor_visual_1{};
    uint32_t meteor_visual_2{};
    uint32_t meteor_visual_3{};
    uint32_t meteor_visual_4{};
    uint32_t meteor_visual_5{};
    double meteor_radius_0{};
    double meteor_radius_1{};
};
inline bool read(BinaryReader &input, RockFieldDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.meteor_count)) return false;
    if (!input.read_u32(out.iron_count)) return false;
    if (!input.read_u32(out.saw_count)) return false;
    if (!input.read_f64(out.planet_radius)) return false;
    if (out.planet_radius < 0) return false;
    if (!input.read_f64(out.meteor_coin_chance)) return false;
    if (out.meteor_coin_chance < 0) return false;
    if (!input.read_f64(out.meteor_heal_chance)) return false;
    if (out.meteor_heal_chance < 0) return false;
    if (!input.read_f64(out.meteor_magnet_chance)) return false;
    if (out.meteor_magnet_chance < 0) return false;
    if (!input.read_f64(out.saw_speed)) return false;
    if (out.saw_speed < 0) return false;
    if (!input.read_f64(out.saw_power)) return false;
    if (out.saw_power < 0) return false;
    if (!input.read_f64(out.saw_life)) return false;
    if (out.saw_life < 0) return false;
    if (!input.read_u32(out.meteor)) return false;
    if (out.meteor < 1) return false;
    if (!input.read_u32(out.iron)) return false;
    if (out.iron < 1) return false;
    if (!input.read_u32(out.saw)) return false;
    if (out.saw < 1) return false;
    if (!input.read_u32(out.meteor_visual_0)) return false;
    if (out.meteor_visual_0 < 1) return false;
    if (!input.read_u32(out.meteor_visual_1)) return false;
    if (out.meteor_visual_1 < 1) return false;
    if (!input.read_u32(out.meteor_visual_2)) return false;
    if (out.meteor_visual_2 < 1) return false;
    if (!input.read_u32(out.meteor_visual_3)) return false;
    if (out.meteor_visual_3 < 1) return false;
    if (!input.read_u32(out.meteor_visual_4)) return false;
    if (out.meteor_visual_4 < 1) return false;
    if (!input.read_u32(out.meteor_visual_5)) return false;
    if (out.meteor_visual_5 < 1) return false;
    if (!input.read_f64(out.meteor_radius_0)) return false;
    if (out.meteor_radius_0 < 0) return false;
    if (!input.read_f64(out.meteor_radius_1)) return false;
    if (out.meteor_radius_1 < 0) return false;
    return true;
}
struct GravityDefinition {
    uint32_t id{};
    double life{};
    double radius{};
    double pull{};
};
inline bool read(BinaryReader &input, GravityDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.pull)) return false;
    if (out.pull < 0) return false;
    return true;
}
struct WarpDefinition {
    uint32_t id{};
    double radius{};
    double life{};
    double bonus_time{};
};
inline bool read(BinaryReader &input, WarpDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.bonus_time)) return false;
    if (out.bonus_time < 0) return false;
    return true;
}
struct CometDefinition {
    uint32_t id{};
    double interval_min{};
    double interval_max{};
    double speed{};
    double rare_chance{};
    double rare_after{};
    double rare_hp_mult{};
    double warp_chance{};
};
inline bool read(BinaryReader &input, CometDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.interval_min)) return false;
    if (out.interval_min < 0) return false;
    if (!input.read_f64(out.interval_max)) return false;
    if (out.interval_max < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.rare_chance)) return false;
    if (out.rare_chance < 0) return false;
    if (!input.read_f64(out.rare_after)) return false;
    if (out.rare_after < 0) return false;
    if (!input.read_f64(out.rare_hp_mult)) return false;
    if (out.rare_hp_mult < 0) return false;
    if (!input.read_f64(out.warp_chance)) return false;
    if (out.warp_chance < 0) return false;
    return true;
}
struct NumericTraitLevel {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    double area_bonus{};
    double shot_bonus{};
    double full_gauge_rate{};
    double charge_bonus{};
    double capacity_bonus{};
    double crit_bonus{};
    double speed_bonus{};
    double attack_bonus{};
    double pickup_bonus{};
    double length_bonus{};
    double glide_bonus{};
};
inline bool read(BinaryReader &input, NumericTraitLevel &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.area_bonus)) return false;
    if (out.area_bonus < 0) return false;
    if (!input.read_f64(out.shot_bonus)) return false;
    if (out.shot_bonus < 0) return false;
    if (!input.read_f64(out.full_gauge_rate)) return false;
    if (out.full_gauge_rate < 0) return false;
    if (!input.read_f64(out.charge_bonus)) return false;
    if (out.charge_bonus < 0) return false;
    if (!input.read_f64(out.capacity_bonus)) return false;
    if (out.capacity_bonus < 0) return false;
    if (!input.read_f64(out.crit_bonus)) return false;
    if (out.crit_bonus < 0) return false;
    if (!input.read_f64(out.speed_bonus)) return false;
    if (out.speed_bonus < 0) return false;
    if (!input.read_f64(out.attack_bonus)) return false;
    if (out.attack_bonus < 0) return false;
    if (!input.read_f64(out.pickup_bonus)) return false;
    if (out.pickup_bonus < 0) return false;
    if (!input.read_f64(out.length_bonus)) return false;
    if (out.length_bonus < 0) return false;
    if (!input.read_f64(out.glide_bonus)) return false;
    if (out.glide_bonus < 0) return false;
    return true;
}
struct PostMaxChargeDefinition {
    uint32_t id{};
    double increment{};
    double minimum_ratio{};
    double minimum_time{};
};
inline bool read(BinaryReader &input, PostMaxChargeDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.increment)) return false;
    if (out.increment < 0) return false;
    if (!input.read_f64(out.minimum_ratio)) return false;
    if (out.minimum_ratio < 0) return false;
    if (out.minimum_ratio > 1) return false;
    if (!input.read_f64(out.minimum_time)) return false;
    if (out.minimum_time < 0) return false;
    return true;
}
struct PostMaxCritDefinition {
    uint32_t id{};
    double trait_maximum{};
    double trained_bonus{};
    double increment{};
};
inline bool read(BinaryReader &input, PostMaxCritDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.trait_maximum)) return false;
    if (out.trait_maximum < 0) return false;
    if (!input.read_f64(out.trained_bonus)) return false;
    if (out.trained_bonus < 0) return false;
    if (!input.read_f64(out.increment)) return false;
    if (out.increment < 0) return false;
    return true;
}
struct PostMaxMotionDefinition {
    uint32_t id{};
    double max_speed_increment{};
};
inline bool read(BinaryReader &input, PostMaxMotionDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.max_speed_increment)) return false;
    if (out.max_speed_increment < 0) return false;
    return true;
}
struct PostMaxWeaponPowerDefinition {
    uint32_t id{};
    uint32_t equipment{};
    double damage_increment{};
    double followup_increment{};
};
inline bool read(BinaryReader &input, PostMaxWeaponPowerDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_f64(out.damage_increment)) return false;
    if (out.damage_increment < 0) return false;
    if (!input.read_f64(out.followup_increment)) return false;
    if (out.followup_increment < 0) return false;
    return true;
}
struct PostMaxPickupDefinition {
    uint32_t id{};
    double xp_radius_increment{};
};
inline bool read(BinaryReader &input, PostMaxPickupDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.xp_radius_increment)) return false;
    if (out.xp_radius_increment < 0) return false;
    return true;
}
struct PostMaxDrawDefinition {
    uint32_t id{};
    double line_length_increment{};
};
inline bool read(BinaryReader &input, PostMaxDrawDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.line_length_increment)) return false;
    if (out.line_length_increment < 0) return false;
    return true;
}
struct ScatterDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double interval{};
    double damage{};
    uint32_t shots{};
    double life{};
    double spread{};
    double knock{};
};
inline bool read(BinaryReader &input, ScatterDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_u32(out.shots)) return false;
    if (out.shots < 1) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    return true;
}
struct ScatterPostDefinition {
    uint32_t id{};
    double interval_increment{};
    double projectile_increment{};
    double duration_increment{};
    double knockback_increment{};
    double minimum_ratio{};
    double minimum_interval{};
};
inline bool read(BinaryReader &input, ScatterPostDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.interval_increment)) return false;
    if (out.interval_increment < 0) return false;
    if (!input.read_f64(out.projectile_increment)) return false;
    if (out.projectile_increment < 0) return false;
    if (!input.read_f64(out.duration_increment)) return false;
    if (out.duration_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    if (!input.read_f64(out.minimum_ratio)) return false;
    if (out.minimum_ratio < 0) return false;
    if (out.minimum_ratio > 1) return false;
    if (!input.read_f64(out.minimum_interval)) return false;
    if (out.minimum_interval < 0) return false;
    return true;
}
struct RearDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double interval{};
    double damage{};
    double life{};
    double spread{};
    double knock{};
    uint32_t pierce{};
    uint32_t color{};
    double mount_x{};
    double mount_y{};
    double muzzle_distance{};
};
inline bool read(BinaryReader &input, RearDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_u32(out.pierce)) return false;
    if (!input.read_u32(out.color)) return false;
    if (!input.read_f64(out.mount_x)) return false;
    if (!input.read_f64(out.mount_y)) return false;
    if (!input.read_f64(out.muzzle_distance)) return false;
    if (out.muzzle_distance < 0) return false;
    return true;
}
struct RearPostDefinition {
    uint32_t id{};
    double interval_increment{};
    double projectile_increment{};
    double duration_increment{};
    double knockback_increment{};
    double minimum_ratio{};
    double minimum_interval{};
};
inline bool read(BinaryReader &input, RearPostDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.interval_increment)) return false;
    if (out.interval_increment < 0) return false;
    if (!input.read_f64(out.projectile_increment)) return false;
    if (out.projectile_increment < 0) return false;
    if (!input.read_f64(out.duration_increment)) return false;
    if (out.duration_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    if (!input.read_f64(out.minimum_ratio)) return false;
    if (out.minimum_ratio < 0) return false;
    if (out.minimum_ratio > 1) return false;
    if (!input.read_f64(out.minimum_interval)) return false;
    if (out.minimum_interval < 0) return false;
    return true;
}
struct BarrierDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double durability{};
    double revive{};
    double radius{};
    double damage{};
    double shell_radius{};
    double knock{};
};
inline bool read(BinaryReader &input, BarrierDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.durability)) return false;
    if (out.durability < 0) return false;
    if (!input.read_f64(out.revive)) return false;
    if (out.revive < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.shell_radius)) return false;
    if (out.shell_radius < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    return true;
}
struct BarrierPostDefinition {
    uint32_t id{};
    double interval_increment{};
    double knockback_increment{};
    double minimum_ratio{};
    double minimum_interval{};
};
inline bool read(BinaryReader &input, BarrierPostDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.interval_increment)) return false;
    if (out.interval_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    if (!input.read_f64(out.minimum_ratio)) return false;
    if (out.minimum_ratio < 0) return false;
    if (out.minimum_ratio > 1) return false;
    if (!input.read_f64(out.minimum_interval)) return false;
    if (out.minimum_interval < 0) return false;
    return true;
}
struct FullChargeDefinition {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    double multiplier{};
};
inline bool read(BinaryReader &input, FullChargeDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.multiplier)) return false;
    if (out.multiplier < 1) return false;
    return true;
}
struct RampageDefinition {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    double bonus{};
    uint32_t kills{};
    double half_life{};
};
inline bool read(BinaryReader &input, RampageDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.bonus)) return false;
    if (out.bonus < 0) return false;
    if (!input.read_u32(out.kills)) return false;
    if (out.kills < 1) return false;
    if (!input.read_f64(out.half_life)) return false;
    if (out.half_life < 0) return false;
    return true;
}
struct DuplicatorDefinition {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    double chance{};
    double damage{};
    uint32_t maximum{};
    double angle_min{};
    double angle_max{};
};
inline bool read(BinaryReader &input, DuplicatorDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.chance)) return false;
    if (out.chance < 0) return false;
    if (out.chance > 1) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_u32(out.maximum)) return false;
    if (out.maximum < 0) return false;
    if (!input.read_f64(out.angle_min)) return false;
    if (out.angle_min < 0) return false;
    if (!input.read_f64(out.angle_max)) return false;
    if (out.angle_max < 0) return false;
    return true;
}
struct EndBlastDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double radius{};
    double damage{};
    uint32_t secondary{};
    double secondary_radius{};
    double secondary_damage{};
    double secondary_delay{};
    double secondary_step{};
    double knock{};
};
inline bool read(BinaryReader &input, EndBlastDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_u32(out.secondary)) return false;
    if (out.secondary < 0) return false;
    if (!input.read_f64(out.secondary_radius)) return false;
    if (out.secondary_radius < 0) return false;
    if (!input.read_f64(out.secondary_damage)) return false;
    if (out.secondary_damage < 0) return false;
    if (!input.read_f64(out.secondary_delay)) return false;
    if (out.secondary_delay < 0) return false;
    if (!input.read_f64(out.secondary_step)) return false;
    if (out.secondary_step < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    return true;
}
struct RunUpDefinition {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    double distance{};
    double multiplier{};
    double radius{};
    double area_damage{};
};
inline bool read(BinaryReader &input, RunUpDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.distance)) return false;
    if (out.distance < 0) return false;
    if (!input.read_f64(out.multiplier)) return false;
    if (out.multiplier < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.area_damage)) return false;
    if (out.area_damage < 0) return false;
    return true;
}
struct MinesDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    uint32_t count{};
    double damage{};
    double radius{};
    double life{};
    uint32_t maximum{};
    double trigger{};
    double spread{};
    double range_min{};
    double range_max{};
    double duration_increment{};
    double knockback_increment{};
    double visual_life{};
};
inline bool read(BinaryReader &input, MinesDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_u32(out.maximum)) return false;
    if (out.maximum < 0) return false;
    if (!input.read_f64(out.trigger)) return false;
    if (out.trigger < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.range_min)) return false;
    if (out.range_min < 0) return false;
    if (!input.read_f64(out.range_max)) return false;
    if (out.range_max < 0) return false;
    if (!input.read_f64(out.duration_increment)) return false;
    if (out.duration_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    if (!input.read_f64(out.visual_life)) return false;
    if (out.visual_life < 0) return false;
    return true;
}
struct VortexDefinition {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    double damage{};
    double radius{};
    double kills{};
    double charge{};
    double hold{};
    double collapse{};
};
inline bool read(BinaryReader &input, VortexDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.kills)) return false;
    if (out.kills < 0) return false;
    if (!input.read_f64(out.charge)) return false;
    if (out.charge < 0) return false;
    if (!input.read_f64(out.hold)) return false;
    if (out.hold < 0) return false;
    if (!input.read_f64(out.collapse)) return false;
    if (out.collapse < 0) return false;
    return true;
}
struct CritBeamDefinition {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    double cooldown{};
    double damage{};
    double length{};
    double width{};
    double knock{};
};
inline bool read(BinaryReader &input, CritBeamDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.cooldown)) return false;
    if (out.cooldown < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    return true;
}
struct KnockbackDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double chance{};
    uint32_t chain_limit{};
    double speed{};
    double life{};
    double base_damage{};
    double base_attack{};
    double base_knock{};
    double base_life{};
    double projectile_increment{};
    double duration_increment{};
    double knockback_increment{};
    double area_increment{};
};
inline bool read(BinaryReader &input, KnockbackDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.chance)) return false;
    if (out.chance < 0) return false;
    if (out.chance > 1) return false;
    if (!input.read_u32(out.chain_limit)) return false;
    if (out.chain_limit > 2147483646) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.base_damage)) return false;
    if (out.base_damage < 0) return false;
    if (!input.read_f64(out.base_attack)) return false;
    if (out.base_attack < 0) return false;
    if (!input.read_f64(out.base_knock)) return false;
    if (out.base_knock < 0) return false;
    if (!input.read_f64(out.base_life)) return false;
    if (out.base_life < 0) return false;
    if (!input.read_f64(out.projectile_increment)) return false;
    if (out.projectile_increment < 0) return false;
    if (!input.read_f64(out.duration_increment)) return false;
    if (out.duration_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    if (!input.read_f64(out.area_increment)) return false;
    if (out.area_increment < 0) return false;
    return true;
}
struct ContactWaveDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double radius{};
    double damage{};
    double knock{};
    double area_increment{};
    double knockback_increment{};
};
inline bool read(BinaryReader &input, ContactWaveDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_f64(out.area_increment)) return false;
    if (out.area_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    return true;
}
struct SonicDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double damage{};
    double speed{};
    double life{};
    double emit_spacing{};
    double min_speed{};
    double nose{};
    double distance{};
    double pulse{};
    double side_speed{};
    double back_speed{};
    double decay{};
    double damage_delay{};
    double area_increment{};
    double duration_increment{};
};
inline bool read(BinaryReader &input, SonicDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.emit_spacing)) return false;
    if (out.emit_spacing < 0) return false;
    if (!input.read_f64(out.min_speed)) return false;
    if (out.min_speed < 0) return false;
    if (!input.read_f64(out.nose)) return false;
    if (out.nose < 0) return false;
    if (!input.read_f64(out.distance)) return false;
    if (out.distance < 0) return false;
    if (!input.read_f64(out.pulse)) return false;
    if (out.pulse < 0) return false;
    if (!input.read_f64(out.side_speed)) return false;
    if (out.side_speed < 0) return false;
    if (!input.read_f64(out.back_speed)) return false;
    if (out.back_speed < 0) return false;
    if (!input.read_f64(out.decay)) return false;
    if (out.decay < 0) return false;
    if (!input.read_f64(out.damage_delay)) return false;
    if (out.damage_delay < 0) return false;
    if (!input.read_f64(out.area_increment)) return false;
    if (out.area_increment < 0) return false;
    if (!input.read_f64(out.duration_increment)) return false;
    if (out.duration_increment < 0) return false;
    return true;
}
struct ContactArcDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    uint32_t chains{};
    uint32_t branches{};
    double damage{};
    double range{};
    double cooldown{};
    double knock{};
    double area_increment{};
    double knockback_increment{};
    double visual_life{};
};
inline bool read(BinaryReader &input, ContactArcDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_u32(out.chains)) return false;
    if (out.chains < 1) return false;
    if (!input.read_u32(out.branches)) return false;
    if (out.branches < 1) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.range)) return false;
    if (out.range < 0) return false;
    if (!input.read_f64(out.cooldown)) return false;
    if (out.cooldown < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_f64(out.area_increment)) return false;
    if (out.area_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    if (!input.read_f64(out.visual_life)) return false;
    if (out.visual_life < 0) return false;
    return true;
}
struct KillSonicDefinition {
    uint32_t id{};
    uint32_t equipment{};
    uint32_t level{};
    int64_t kills{};
    int64_t limit{};
    double radius{};
    double damage{};
    double radius_decay{};
    double damage_decay{};
    double knock{};
    double life{};
};
inline bool read(BinaryReader &input, KillSonicDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.equipment)) return false;
    if (out.equipment < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_i64(out.kills)) return false;
    if (!input.read_i64(out.limit)) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.radius_decay)) return false;
    if (out.radius_decay < 0) return false;
    if (!input.read_f64(out.damage_decay)) return false;
    if (out.damage_decay < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    return true;
}
struct MassTowDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double capture_radius{};
    double hold{};
    double follow{};
    double interval{};
    double shot_speed{};
    double damage{};
    double size_ref{};
    double life{};
    double knock{};
    double clump_spacing{};
    double projectile_increment{};
    double duration_increment{};
    double knockback_increment{};
    double area_increment{};
    double interval_increment{};
    double minimum_ratio{};
    double minimum_interval{};
    uint32_t visible{};
};
inline bool read(BinaryReader &input, MassTowDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.capture_radius)) return false;
    if (out.capture_radius < 0) return false;
    if (!input.read_f64(out.hold)) return false;
    if (out.hold < 0) return false;
    if (!input.read_f64(out.follow)) return false;
    if (out.follow < 0) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.shot_speed)) return false;
    if (out.shot_speed < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.size_ref)) return false;
    if (out.size_ref < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_f64(out.clump_spacing)) return false;
    if (out.clump_spacing < 0) return false;
    if (!input.read_f64(out.projectile_increment)) return false;
    if (out.projectile_increment < 0) return false;
    if (!input.read_f64(out.duration_increment)) return false;
    if (out.duration_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    if (!input.read_f64(out.area_increment)) return false;
    if (out.area_increment < 0) return false;
    if (!input.read_f64(out.interval_increment)) return false;
    if (out.interval_increment < 0) return false;
    if (!input.read_f64(out.minimum_ratio)) return false;
    if (out.minimum_ratio < 0) return false;
    if (!input.read_f64(out.minimum_interval)) return false;
    if (out.minimum_interval < 0) return false;
    if (!input.read_u32(out.visible)) return false;
    if (out.visible < 1) return false;
    return true;
}
struct BipolarDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double damage{};
    double width{};
    double radius_factor{};
    double life{};
    double knock{};
    double min_length{};
    double delay{};
    double visual_life{};
    double area_increment{};
    double knockback_increment{};
    uint32_t color{};
};
inline bool read(BinaryReader &input, BipolarDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.radius_factor)) return false;
    if (out.radius_factor < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.knock)) return false;
    if (out.knock < 0) return false;
    if (!input.read_f64(out.min_length)) return false;
    if (out.min_length < 0) return false;
    if (!input.read_f64(out.delay)) return false;
    if (out.delay < 0) return false;
    if (!input.read_f64(out.visual_life)) return false;
    if (out.visual_life < 0) return false;
    if (!input.read_f64(out.area_increment)) return false;
    if (out.area_increment < 0) return false;
    if (!input.read_f64(out.knockback_increment)) return false;
    if (out.knockback_increment < 0) return false;
    if (!input.read_u32(out.color)) return false;
    return true;
}
struct InterceptorDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    double damage{};
    double interval{};
    double burst_interval{};
    double range{};
    double orbit{};
    double orbit_speed{};
    double target_interval{};
    double shot_radius{};
    double shot_speed{};
    double life{};
    double projectile_increment{};
    double duration_increment{};
    double interval_increment{};
    double minimum_ratio{};
    double minimum_interval{};
    uint32_t count{};
    uint32_t burst{};
    uint32_t color{};
};
inline bool read(BinaryReader &input, InterceptorDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.burst_interval)) return false;
    if (out.burst_interval < 0) return false;
    if (!input.read_f64(out.range)) return false;
    if (out.range < 0) return false;
    if (!input.read_f64(out.orbit)) return false;
    if (out.orbit < 0) return false;
    if (!input.read_f64(out.orbit_speed)) return false;
    if (out.orbit_speed < 0) return false;
    if (!input.read_f64(out.target_interval)) return false;
    if (out.target_interval < 0) return false;
    if (!input.read_f64(out.shot_radius)) return false;
    if (out.shot_radius < 0) return false;
    if (!input.read_f64(out.shot_speed)) return false;
    if (out.shot_speed < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.projectile_increment)) return false;
    if (out.projectile_increment < 0) return false;
    if (!input.read_f64(out.duration_increment)) return false;
    if (out.duration_increment < 0) return false;
    if (!input.read_f64(out.interval_increment)) return false;
    if (out.interval_increment < 0) return false;
    if (!input.read_f64(out.minimum_ratio)) return false;
    if (out.minimum_ratio < 0) return false;
    if (!input.read_f64(out.minimum_interval)) return false;
    if (out.minimum_interval < 0) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 1) return false;
    if (!input.read_u32(out.burst)) return false;
    if (out.burst < 1) return false;
    if (!input.read_u32(out.color)) return false;
    return true;
}
struct DashRangeDroneDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    uint32_t count{};
    double damage{};
    double tail{};
    double hit_radius{};
    double deploy_distance{};
    double idle_spacing{};
    double idle_back{};
    double return_rate{};
    double area_increment{};
};
inline bool read(BinaryReader &input, DashRangeDroneDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (out.weapon < 1) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 2) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.tail)) return false;
    if (out.tail < 0) return false;
    if (!input.read_f64(out.hit_radius)) return false;
    if (out.hit_radius < 0) return false;
    if (!input.read_f64(out.deploy_distance)) return false;
    if (out.deploy_distance < 0) return false;
    if (!input.read_f64(out.idle_spacing)) return false;
    if (out.idle_spacing < 0) return false;
    if (!input.read_f64(out.idle_back)) return false;
    if (out.idle_back < 0) return false;
    if (!input.read_f64(out.return_rate)) return false;
    if (out.return_rate < 0) return false;
    if (!input.read_f64(out.area_increment)) return false;
    if (out.area_increment < 0) return false;
    return true;
}
struct AfterimageDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    uint32_t count{};
    double total{};
    double delay{};
};
inline bool read(BinaryReader &input, AfterimageDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 1) return false;
    if (out.count > 8) return false;
    if (!input.read_f64(out.total)) return false;
    if (out.total < 0) return false;
    if (!input.read_f64(out.delay)) return false;
    if (out.delay < 0.02) return false;
    if (out.delay > 0.5) return false;
    return true;
}
struct FlashSlashDefinition {
    uint32_t id{};
    uint32_t weapon{};
    uint32_t level{};
    uint32_t cuts{};
    uint32_t streaks{};
    double multiplier{};
    double pause{};
    double sweep{};
};
inline bool read(BinaryReader &input, FlashSlashDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.weapon)) return false;
    if (!input.read_u32(out.level)) return false;
    if (out.level < 1) return false;
    if (!input.read_u32(out.cuts)) return false;
    if (out.cuts < 1) return false;
    if (!input.read_u32(out.streaks)) return false;
    if (out.streaks < 1) return false;
    if (!input.read_f64(out.multiplier)) return false;
    if (out.multiplier < 0) return false;
    if (!input.read_f64(out.pause)) return false;
    if (out.pause < 0) return false;
    if (!input.read_f64(out.sweep)) return false;
    if (out.sweep < 0) return false;
    return true;
}
struct BossDefinition {
    uint32_t id{};
    std::string external_id{};
    uint32_t kind{};
    double lock_lead{};
    double horn_width{};
    double horn_length_ratio{};
    double horn_length_ratio_p2{};
    double near_clearance{};
    double reposition_time{};
    double stuck_time{};
    double extract_time{};
    double extract_speed{};
    double turn{};
    double speed{};
    double approach_range{};
    double approach_speed{};
    double kick_trigger_arc{};
};
inline bool read(BinaryReader &input, BossDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_string(out.external_id)) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 4) return false;
    if (!input.read_f64(out.lock_lead)) return false;
    if (out.lock_lead < 0) return false;
    if (!input.read_f64(out.horn_width)) return false;
    if (out.horn_width < 0) return false;
    if (!input.read_f64(out.horn_length_ratio)) return false;
    if (out.horn_length_ratio < 0) return false;
    if (!input.read_f64(out.horn_length_ratio_p2)) return false;
    if (out.horn_length_ratio_p2 < 0) return false;
    if (!input.read_f64(out.near_clearance)) return false;
    if (out.near_clearance < 0) return false;
    if (!input.read_f64(out.reposition_time)) return false;
    if (out.reposition_time < 0) return false;
    if (!input.read_f64(out.stuck_time)) return false;
    if (out.stuck_time < 0) return false;
    if (!input.read_f64(out.extract_time)) return false;
    if (out.extract_time < 0) return false;
    if (!input.read_f64(out.extract_speed)) return false;
    if (out.extract_speed < 0) return false;
    if (!input.read_f64(out.turn)) return false;
    if (out.turn < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.approach_range)) return false;
    if (out.approach_range < 0) return false;
    if (!input.read_f64(out.approach_speed)) return false;
    if (out.approach_speed < 0) return false;
    if (!input.read_f64(out.kick_trigger_arc)) return false;
    if (out.kick_trigger_arc < 0) return false;
    return true;
}
struct BossTechniqueDefinition {
    uint32_t id{};
    uint32_t boss{};
    std::string external_id{};
    uint32_t kind{};
    uint32_t phase{};
    bool track_during_warn{};
    double warn{};
    double active{};
    double recover{};
    double cd{};
    double damage{};
    double distance{};
    double post_gap{};
    double reach{};
    double hold{};
    double return_speed{};
    double approach_speed_start{};
    double approach_accel{};
    double approach_speed_max{};
    double approach_turn{};
    double approach_min{};
    double approach_max{};
    double stop_range{};
    double twist_time{};
    double twist{};
    double stop_time{};
    double stop_decel{};
    double windup_twist{};
    double arc{};
    double return_time{};
    double lock_time{};
    double aim_turn{};
    double back_speed{};
    double head_length{};
    double width{};
    double speed{};
    double boom_interval{};
    double boom_ahead{};
    double stop_decay{};
    double shatter_time{};
    uint32_t passes{};
    double overshoot{};
    double brake_time{};
    double brake_speed_ratio{};
    double turn_time{};
    double turn_lock{};
    double head_lead{};
    double windup_turn{};
    double pull{};
    double swing_time{};
    double swing_turn{};
    double release_offset{};
    double recharge{};
    double wave_speed{};
    double wave_start{};
    double wave_max{};
    double wave_half_angle{};
    double wave_width{};
    double aim_lock{};
    double min_run{};
    double circle_turn{};
    double circle_speed{};
    double circle_late_time{};
    double circle_speed_late{};
    double circle_decel{};
    double circle_accel{};
    double align_angle{};
    double align_min_distance{};
    double align_min_time{};
    double circle_max_time{};
    double glow_angle{};
    double end_time{};
    double end_decay{};
    uint32_t cuts{};
    double first_windup{};
    double lunge_speed{};
    double lunge_decay{};
    double slash_min{};
    double slash_max{};
    double slash_angle{};
    double slash_length{};
    double slash_width{};
    double slash_hit_time{};
    double cut_gap{};
};
inline bool read(BinaryReader &input, BossTechniqueDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_string(out.external_id)) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 107) return false;
    if (!input.read_u32(out.phase)) return false;
    if (out.phase < 1) return false;
    if (out.phase > 3) return false;
    if (!input.read_bool(out.track_during_warn)) return false;
    if (!input.read_f64(out.warn)) return false;
    if (out.warn < 0) return false;
    if (!input.read_f64(out.active)) return false;
    if (out.active < 0) return false;
    if (!input.read_f64(out.recover)) return false;
    if (out.recover < 0) return false;
    if (!input.read_f64(out.cd)) return false;
    if (out.cd < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.distance)) return false;
    if (out.distance < 0) return false;
    if (!input.read_f64(out.post_gap)) return false;
    if (out.post_gap < 0) return false;
    if (!input.read_f64(out.reach)) return false;
    if (out.reach < 0) return false;
    if (!input.read_f64(out.hold)) return false;
    if (out.hold < 0) return false;
    if (!input.read_f64(out.return_speed)) return false;
    if (out.return_speed < 0) return false;
    if (!input.read_f64(out.approach_speed_start)) return false;
    if (out.approach_speed_start < 0) return false;
    if (!input.read_f64(out.approach_accel)) return false;
    if (out.approach_accel < 0) return false;
    if (!input.read_f64(out.approach_speed_max)) return false;
    if (out.approach_speed_max < 0) return false;
    if (!input.read_f64(out.approach_turn)) return false;
    if (out.approach_turn < 0) return false;
    if (!input.read_f64(out.approach_min)) return false;
    if (out.approach_min < 0) return false;
    if (!input.read_f64(out.approach_max)) return false;
    if (out.approach_max < 0) return false;
    if (!input.read_f64(out.stop_range)) return false;
    if (out.stop_range < 0) return false;
    if (!input.read_f64(out.twist_time)) return false;
    if (out.twist_time < 0) return false;
    if (!input.read_f64(out.twist)) return false;
    if (out.twist < 0) return false;
    if (!input.read_f64(out.stop_time)) return false;
    if (out.stop_time < 0) return false;
    if (!input.read_f64(out.stop_decel)) return false;
    if (out.stop_decel < 0) return false;
    if (!input.read_f64(out.windup_twist)) return false;
    if (out.windup_twist < 0) return false;
    if (!input.read_f64(out.arc)) return false;
    if (out.arc < 0) return false;
    if (!input.read_f64(out.return_time)) return false;
    if (out.return_time < 0) return false;
    if (!input.read_f64(out.lock_time)) return false;
    if (out.lock_time < 0) return false;
    if (!input.read_f64(out.aim_turn)) return false;
    if (out.aim_turn < 0) return false;
    if (!input.read_f64(out.back_speed)) return false;
    if (out.back_speed < 0) return false;
    if (!input.read_f64(out.head_length)) return false;
    if (out.head_length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.boom_interval)) return false;
    if (out.boom_interval < 0) return false;
    if (!input.read_f64(out.boom_ahead)) return false;
    if (out.boom_ahead < 0) return false;
    if (!input.read_f64(out.stop_decay)) return false;
    if (out.stop_decay < 0) return false;
    if (!input.read_f64(out.shatter_time)) return false;
    if (out.shatter_time < 0) return false;
    if (!input.read_u32(out.passes)) return false;
    if (out.passes < 1) return false;
    if (!input.read_f64(out.overshoot)) return false;
    if (out.overshoot < 0) return false;
    if (!input.read_f64(out.brake_time)) return false;
    if (out.brake_time < 0) return false;
    if (!input.read_f64(out.brake_speed_ratio)) return false;
    if (out.brake_speed_ratio < 0) return false;
    if (!input.read_f64(out.turn_time)) return false;
    if (out.turn_time < 0) return false;
    if (!input.read_f64(out.turn_lock)) return false;
    if (out.turn_lock < 0) return false;
    if (!input.read_f64(out.head_lead)) return false;
    if (out.head_lead < 0) return false;
    if (!input.read_f64(out.windup_turn)) return false;
    if (out.windup_turn < 0) return false;
    if (!input.read_f64(out.pull)) return false;
    if (out.pull < 0) return false;
    if (!input.read_f64(out.swing_time)) return false;
    if (out.swing_time < 0) return false;
    if (!input.read_f64(out.swing_turn)) return false;
    if (out.swing_turn < 0) return false;
    if (!input.read_f64(out.release_offset)) return false;
    if (out.release_offset < 0) return false;
    if (!input.read_f64(out.recharge)) return false;
    if (out.recharge < 0) return false;
    if (!input.read_f64(out.wave_speed)) return false;
    if (out.wave_speed < 0) return false;
    if (!input.read_f64(out.wave_start)) return false;
    if (out.wave_start < 0) return false;
    if (!input.read_f64(out.wave_max)) return false;
    if (out.wave_max < 0) return false;
    if (!input.read_f64(out.wave_half_angle)) return false;
    if (out.wave_half_angle < 0) return false;
    if (!input.read_f64(out.wave_width)) return false;
    if (out.wave_width < 0) return false;
    if (!input.read_f64(out.aim_lock)) return false;
    if (out.aim_lock < 0) return false;
    if (!input.read_f64(out.min_run)) return false;
    if (out.min_run < 0) return false;
    if (!input.read_f64(out.circle_turn)) return false;
    if (out.circle_turn < 0) return false;
    if (!input.read_f64(out.circle_speed)) return false;
    if (out.circle_speed < 0) return false;
    if (!input.read_f64(out.circle_late_time)) return false;
    if (out.circle_late_time < 0) return false;
    if (!input.read_f64(out.circle_speed_late)) return false;
    if (out.circle_speed_late < 0) return false;
    if (!input.read_f64(out.circle_decel)) return false;
    if (out.circle_decel < 0) return false;
    if (!input.read_f64(out.circle_accel)) return false;
    if (out.circle_accel < 0) return false;
    if (!input.read_f64(out.align_angle)) return false;
    if (out.align_angle < 0) return false;
    if (!input.read_f64(out.align_min_distance)) return false;
    if (out.align_min_distance < 0) return false;
    if (!input.read_f64(out.align_min_time)) return false;
    if (out.align_min_time < 0) return false;
    if (!input.read_f64(out.circle_max_time)) return false;
    if (out.circle_max_time < 0) return false;
    if (!input.read_f64(out.glow_angle)) return false;
    if (out.glow_angle < 0) return false;
    if (!input.read_f64(out.end_time)) return false;
    if (out.end_time < 0) return false;
    if (!input.read_f64(out.end_decay)) return false;
    if (out.end_decay < 0) return false;
    if (!input.read_u32(out.cuts)) return false;
    if (out.cuts < 1) return false;
    if (!input.read_f64(out.first_windup)) return false;
    if (out.first_windup < 0) return false;
    if (!input.read_f64(out.lunge_speed)) return false;
    if (out.lunge_speed < 0) return false;
    if (!input.read_f64(out.lunge_decay)) return false;
    if (out.lunge_decay < 0) return false;
    if (!input.read_f64(out.slash_min)) return false;
    if (out.slash_min < 0) return false;
    if (!input.read_f64(out.slash_max)) return false;
    if (out.slash_max < 0) return false;
    if (!input.read_f64(out.slash_angle)) return false;
    if (out.slash_angle < 0) return false;
    if (!input.read_f64(out.slash_length)) return false;
    if (out.slash_length < 0) return false;
    if (!input.read_f64(out.slash_width)) return false;
    if (out.slash_width < 0) return false;
    if (!input.read_f64(out.slash_hit_time)) return false;
    if (out.slash_hit_time < 0) return false;
    if (!input.read_f64(out.cut_gap)) return false;
    if (out.cut_gap < 0) return false;
    return true;
}
struct BossTechniqueStage {
    uint32_t id{};
    uint32_t technique{};
    uint32_t command{};
    double at{};
};
inline bool read(BinaryReader &input, BossTechniqueStage &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.command)) return false;
    if (out.command > 7) return false;
    if (!input.read_f64(out.at)) return false;
    if (out.at < 0) return false;
    return true;
}
struct BossBodyDefinition {
    uint32_t id{};
    uint32_t boss{};
    uint32_t enemy{};
    bool hp_floor_enabled{};
    double entrance_time{};
    double initial_wait{};
    double phase_threshold{};
    double phase_time{};
    double final_beam_width{};
    double final_reach{};
    double final_warn_width{};
    double final_widen_time{};
};
inline bool read(BinaryReader &input, BossBodyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (!input.read_bool(out.hp_floor_enabled)) return false;
    if (!input.read_f64(out.entrance_time)) return false;
    if (out.entrance_time < 0) return false;
    if (!input.read_f64(out.initial_wait)) return false;
    if (out.initial_wait < 0) return false;
    if (!input.read_f64(out.phase_threshold)) return false;
    if (out.phase_threshold < 0) return false;
    if (!input.read_f64(out.phase_time)) return false;
    if (out.phase_time < 0) return false;
    if (!input.read_f64(out.final_beam_width)) return false;
    if (out.final_beam_width < 0) return false;
    if (!input.read_f64(out.final_reach)) return false;
    if (out.final_reach < 0) return false;
    if (!input.read_f64(out.final_warn_width)) return false;
    if (out.final_warn_width < 0) return false;
    if (!input.read_f64(out.final_widen_time)) return false;
    if (out.final_widen_time < 0) return false;
    return true;
}
struct BossFinishDefinition {
    uint32_t id{};
    double replay_window{};
    double slow_time{};
    double zoom{};
    double blast_time{};
    double relic_appear_time{};
    double relic_hold_time{};
    double relic_collect_time{};
    double clear_time{};
    double time_up_charge_time{};
};
inline bool read(BinaryReader &input, BossFinishDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.replay_window)) return false;
    if (out.replay_window < 0) return false;
    if (!input.read_f64(out.slow_time)) return false;
    if (out.slow_time < 0) return false;
    if (!input.read_f64(out.zoom)) return false;
    if (out.zoom < 0) return false;
    if (!input.read_f64(out.blast_time)) return false;
    if (out.blast_time < 0) return false;
    if (!input.read_f64(out.relic_appear_time)) return false;
    if (out.relic_appear_time < 0) return false;
    if (!input.read_f64(out.relic_hold_time)) return false;
    if (out.relic_hold_time < 0) return false;
    if (!input.read_f64(out.relic_collect_time)) return false;
    if (out.relic_collect_time < 0) return false;
    if (!input.read_f64(out.clear_time)) return false;
    if (out.clear_time < 0) return false;
    if (!input.read_f64(out.time_up_charge_time)) return false;
    if (out.time_up_charge_time < 0) return false;
    return true;
}
struct BossFlowProgram {
    uint32_t id{};
    uint32_t boss{};
    double maximum_stamina{};
    double partial_rest{};
    double empty_rest{};
    bool idle_only{};
    bool allow_parallel{};
    bool has_bias{};
};
inline bool read(BinaryReader &input, BossFlowProgram &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_f64(out.maximum_stamina)) return false;
    if (out.maximum_stamina < 0) return false;
    if (!input.read_f64(out.partial_rest)) return false;
    if (out.partial_rest < 0) return false;
    if (!input.read_f64(out.empty_rest)) return false;
    if (out.empty_rest < 0) return false;
    if (!input.read_bool(out.idle_only)) return false;
    if (!input.read_bool(out.allow_parallel)) return false;
    if (!input.read_bool(out.has_bias)) return false;
    return true;
}
struct BossFlowSection {
    uint32_t id{};
    uint32_t flow{};
    uint32_t order{};
    uint32_t request{};
    double cap{};
    bool has_budget{};
    double budget{};
    uint32_t action_count{};
    double action_interval{};
    bool has_timeout{};
    double timeout{};
    bool has_fallback{};
    uint32_t fallback{};
    uint32_t next{};
    bool filter_groups{};
    bool filter_allowed{};
    bool avoid_repeat{};
};
inline bool read(BinaryReader &input, BossFlowSection &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.flow)) return false;
    if (!input.read_u32(out.order)) return false;
    if (!input.read_u32(out.request)) return false;
    if (out.request > 3) return false;
    if (!input.read_f64(out.cap)) return false;
    if (out.cap < 0) return false;
    if (!input.read_bool(out.has_budget)) return false;
    if (!input.read_f64(out.budget)) return false;
    if (out.budget < 0) return false;
    if (!input.read_u32(out.action_count)) return false;
    if (out.action_count < 1) return false;
    if (!input.read_f64(out.action_interval)) return false;
    if (out.action_interval < 0) return false;
    if (!input.read_bool(out.has_timeout)) return false;
    if (!input.read_f64(out.timeout)) return false;
    if (out.timeout < 0) return false;
    if (!input.read_bool(out.has_fallback)) return false;
    if (!input.read_u32(out.fallback)) return false;
    if (!input.read_u32(out.next)) return false;
    if (!input.read_bool(out.filter_groups)) return false;
    if (!input.read_bool(out.filter_allowed)) return false;
    if (!input.read_bool(out.avoid_repeat)) return false;
    return true;
}
struct BossFlowCondition {
    uint32_t id{};
    double minimum{};
    double maximum{};
    double angle{};
    double half_angle{};
    uint32_t minimum_phase{};
};
inline bool read(BinaryReader &input, BossFlowCondition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.minimum)) return false;
    if (out.minimum < 0) return false;
    if (!input.read_f64(out.maximum)) return false;
    if (out.maximum < 0) return false;
    if (!input.read_f64(out.angle)) return false;
    if (!input.read_f64(out.half_angle)) return false;
    if (out.half_angle < 0) return false;
    if (!input.read_u32(out.minimum_phase)) return false;
    if (out.minimum_phase < 1) return false;
    return true;
}
struct BossFlowNode {
    uint32_t id{};
    uint32_t flow{};
    uint32_t kind{};
    double seconds{};
    uint32_t technique{};
    uint32_t condition{};
    uint32_t participant{};
};
inline bool read(BinaryReader &input, BossFlowNode &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.flow)) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 4) return false;
    if (!input.read_f64(out.seconds)) return false;
    if (out.seconds < 0) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.condition)) return false;
    if (!input.read_u32(out.participant)) return false;
    return true;
}
struct BossFlowChild {
    uint32_t id{};
    uint32_t parent{};
    uint32_t child{};
    uint32_t order{};
};
inline bool read(BinaryReader &input, BossFlowChild &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.parent)) return false;
    if (!input.read_u32(out.child)) return false;
    if (!input.read_u32(out.order)) return false;
    return true;
}
struct BossFlowAction {
    uint32_t id{};
    uint32_t flow{};
    std::string external_id{};
    uint32_t node{};
    uint32_t condition{};
    uint32_t category{};
    uint32_t label{};
    std::string group{};
    double cost{};
    double weight{};
    double post_gap{};
    bool exclusive{};
};
inline bool read(BinaryReader &input, BossFlowAction &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.flow)) return false;
    if (!input.read_string(out.external_id)) return false;
    if (!input.read_u32(out.node)) return false;
    if (!input.read_u32(out.condition)) return false;
    if (!input.read_u32(out.category)) return false;
    if (out.category > 2) return false;
    if (!input.read_u32(out.label)) return false;
    if (out.label > 2) return false;
    if (!input.read_string(out.group)) return false;
    if (!input.read_f64(out.cost)) return false;
    if (out.cost < 0) return false;
    if (!input.read_f64(out.weight)) return false;
    if (out.weight < 0) return false;
    if (!input.read_f64(out.post_gap)) return false;
    if (out.post_gap < 0) return false;
    if (!input.read_bool(out.exclusive)) return false;
    return true;
}
struct BossFlowFilter {
    uint32_t id{};
    uint32_t section{};
    uint32_t kind{};
    std::string value{};
};
inline bool read(BinaryReader &input, BossFlowFilter &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.section)) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 3) return false;
    if (!input.read_string(out.value)) return false;
    return true;
}
struct BossFlowWeight {
    uint32_t id{};
    uint32_t section{};
    int64_t previous{};
    uint32_t category{};
    double weight{};
};
inline bool read(BinaryReader &input, BossFlowWeight &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.section)) return false;
    if (!input.read_i64(out.previous)) return false;
    if (out.previous < -1) return false;
    if (out.previous > 3) return false;
    if (!input.read_u32(out.category)) return false;
    if (out.category > 3) return false;
    if (!input.read_f64(out.weight)) return false;
    if (out.weight < 0) return false;
    return true;
}
struct BossFlowForbidden {
    uint32_t id{};
    uint32_t section{};
    std::string left{};
    std::string right{};
};
inline bool read(BinaryReader &input, BossFlowForbidden &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.section)) return false;
    if (!input.read_string(out.left)) return false;
    if (!input.read_string(out.right)) return false;
    return true;
}
struct HeroStar {
    uint32_t id{};
    uint32_t hero{};
    double x{};
    double y{};
};
inline bool read(BinaryReader &input, HeroStar &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.hero)) return false;
    if (!input.read_f64(out.x)) return false;
    if (!input.read_f64(out.y)) return false;
    return true;
}
struct HeroLink {
    uint32_t id{};
    uint32_t hero{};
    uint32_t a{};
    uint32_t b{};
};
inline bool read(BinaryReader &input, HeroLink &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.hero)) return false;
    if (!input.read_u32(out.a)) return false;
    if (!input.read_u32(out.b)) return false;
    return true;
}
struct HeroConfig {
    uint32_t id{};
    double scale{};
    double glow_range{};
    double guard_range{};
    double star_radius{};
    double next_time{};
    double spacing{};
    double first_min{};
    double first_max{};
    double second_min{};
    double second_max{};
    uint32_t guards{};
};
inline bool read(BinaryReader &input, HeroConfig &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_f64(out.scale)) return false;
    if (out.scale < 0) return false;
    if (!input.read_f64(out.glow_range)) return false;
    if (out.glow_range < 0) return false;
    if (!input.read_f64(out.guard_range)) return false;
    if (out.guard_range < 0) return false;
    if (!input.read_f64(out.star_radius)) return false;
    if (out.star_radius < 0) return false;
    if (!input.read_f64(out.next_time)) return false;
    if (out.next_time < 0) return false;
    if (!input.read_f64(out.spacing)) return false;
    if (out.spacing < 0) return false;
    if (!input.read_f64(out.first_min)) return false;
    if (out.first_min < 0) return false;
    if (!input.read_f64(out.first_max)) return false;
    if (out.first_max < 0) return false;
    if (!input.read_f64(out.second_min)) return false;
    if (out.second_min < 0) return false;
    if (!input.read_f64(out.second_max)) return false;
    if (out.second_max < 0) return false;
    if (!input.read_u32(out.guards)) return false;
    return true;
}
struct PerseusDefinition {
    uint32_t id{};
    uint32_t hero{};
    double boss_stun{};
};
inline bool read(BinaryReader &input, PerseusDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.hero)) return false;
    if (!input.read_f64(out.boss_stun)) return false;
    if (out.boss_stun < 0) return false;
    return true;
}
struct LeoDefinition {
    uint32_t id{};
    uint32_t hero{};
    double width_mult{};
};
inline bool read(BinaryReader &input, LeoDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.hero)) return false;
    if (!input.read_f64(out.width_mult)) return false;
    if (out.width_mult < 0) return false;
    return true;
}
struct GeminiDefinition {
    uint32_t id{};
    uint32_t hero{};
};
inline bool read(BinaryReader &input, GeminiDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.hero)) return false;
    return true;
}
struct HerculesDefinition {
    uint32_t id{};
    uint32_t hero{};
    double interval{};
    double fall_time{};
    double power{};
    double radius{};
    double burn_time{};
    double burn_power{};
};
inline bool read(BinaryReader &input, HerculesDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.hero)) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.fall_time)) return false;
    if (out.fall_time < 0) return false;
    if (!input.read_f64(out.power)) return false;
    if (out.power < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.burn_time)) return false;
    if (out.burn_time < 0) return false;
    if (!input.read_f64(out.burn_power)) return false;
    if (out.burn_power < 0) return false;
    return true;
}
struct CentaurusBodyDefinition {
    uint32_t id{};
    uint32_t body{};
    uint32_t guard{};
    double keep_min{};
    double keep_max{};
    double guard_refill{};
    double guard_search{};
    double guard_scan{};
    double sail_guard_min{};
    double sail_guard_max{};
    double sail_guard_speed{};
    double sail_guard_wobble{};
    double bow_reach{};
    double path_cos{};
    double path_min{};
    double path_max{};
    double path_hold{};
    double retreat_trigger{};
    double retreat_far{};
    double retreat_max{};
    double retreat_turn{};
    double retreat_cd{};
    double leap_trigger{};
    double leap_distance{};
    double leap_time{};
    double leap_cd{};
    double run_speed{};
    double run_speed_p2{};
    uint32_t guard_count{};
    uint32_t guard_min{};
};
inline bool read(BinaryReader &input, CentaurusBodyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.body)) return false;
    if (!input.read_u32(out.guard)) return false;
    if (!input.read_f64(out.keep_min)) return false;
    if (out.keep_min < 0) return false;
    if (!input.read_f64(out.keep_max)) return false;
    if (out.keep_max < 0) return false;
    if (!input.read_f64(out.guard_refill)) return false;
    if (out.guard_refill < 0) return false;
    if (!input.read_f64(out.guard_search)) return false;
    if (out.guard_search < 0) return false;
    if (!input.read_f64(out.guard_scan)) return false;
    if (out.guard_scan < 0) return false;
    if (!input.read_f64(out.sail_guard_min)) return false;
    if (out.sail_guard_min < 0) return false;
    if (!input.read_f64(out.sail_guard_max)) return false;
    if (out.sail_guard_max < 0) return false;
    if (!input.read_f64(out.sail_guard_speed)) return false;
    if (out.sail_guard_speed < 0) return false;
    if (!input.read_f64(out.sail_guard_wobble)) return false;
    if (out.sail_guard_wobble < 0) return false;
    if (!input.read_f64(out.bow_reach)) return false;
    if (out.bow_reach < 0) return false;
    if (!input.read_f64(out.path_cos)) return false;
    if (out.path_cos < 0) return false;
    if (!input.read_f64(out.path_min)) return false;
    if (out.path_min < 0) return false;
    if (!input.read_f64(out.path_max)) return false;
    if (out.path_max < 0) return false;
    if (!input.read_f64(out.path_hold)) return false;
    if (out.path_hold < 0) return false;
    if (!input.read_f64(out.retreat_trigger)) return false;
    if (out.retreat_trigger < 0) return false;
    if (!input.read_f64(out.retreat_far)) return false;
    if (out.retreat_far < 0) return false;
    if (!input.read_f64(out.retreat_max)) return false;
    if (out.retreat_max < 0) return false;
    if (!input.read_f64(out.retreat_turn)) return false;
    if (out.retreat_turn < 0) return false;
    if (!input.read_f64(out.retreat_cd)) return false;
    if (out.retreat_cd < 0) return false;
    if (!input.read_f64(out.leap_trigger)) return false;
    if (out.leap_trigger < 0) return false;
    if (!input.read_f64(out.leap_distance)) return false;
    if (out.leap_distance < 0) return false;
    if (!input.read_f64(out.leap_time)) return false;
    if (out.leap_time < 0) return false;
    if (!input.read_f64(out.leap_cd)) return false;
    if (out.leap_cd < 0) return false;
    if (!input.read_f64(out.run_speed)) return false;
    if (out.run_speed < 0) return false;
    if (!input.read_f64(out.run_speed_p2)) return false;
    if (out.run_speed_p2 < 0) return false;
    if (!input.read_u32(out.guard_count)) return false;
    if (out.guard_count < 0) return false;
    if (!input.read_u32(out.guard_min)) return false;
    if (out.guard_min < 0) return false;
    return true;
}
struct CentaurusVolleyDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t count{};
    double interval{};
    double radius{};
    double travel{};
    uint32_t projectile{};
};
inline bool read(BinaryReader &input, CentaurusVolleyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 1) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.travel)) return false;
    if (out.travel < 0) return false;
    if (!input.read_u32(out.projectile)) return false;
    return true;
}
struct CentaurusRearDefinition {
    uint32_t id{};
    uint32_t technique{};
    double back_offset{};
    double radius{};
};
inline bool read(BinaryReader &input, CentaurusRearDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.back_offset)) return false;
    if (out.back_offset < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    return true;
}
struct CentaurusRainDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t traces{};
    uint32_t arrows_per_step{};
    double arrow_gap{};
    double circle_radius{};
    double drop_delay{};
    double drop_height{};
    double fade{};
    double fall{};
    double forward{};
    double linger{};
    double trace_bend{};
    double trace_gap{};
    double trace_length{};
    double trace_speed{};
    double arrow_radius{};
    double arrow_length{};
    uint32_t projectile{};
};
inline bool read(BinaryReader &input, CentaurusRainDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.traces)) return false;
    if (out.traces < 1) return false;
    if (!input.read_u32(out.arrows_per_step)) return false;
    if (out.arrows_per_step < 1) return false;
    if (!input.read_f64(out.arrow_gap)) return false;
    if (out.arrow_gap < 0) return false;
    if (!input.read_f64(out.circle_radius)) return false;
    if (out.circle_radius < 0) return false;
    if (!input.read_f64(out.drop_delay)) return false;
    if (out.drop_delay < 0) return false;
    if (!input.read_f64(out.drop_height)) return false;
    if (out.drop_height < 0) return false;
    if (!input.read_f64(out.fade)) return false;
    if (out.fade < 0) return false;
    if (!input.read_f64(out.fall)) return false;
    if (out.fall < 0) return false;
    if (!input.read_f64(out.forward)) return false;
    if (out.forward < 0) return false;
    if (!input.read_f64(out.linger)) return false;
    if (out.linger < 0) return false;
    if (!input.read_f64(out.trace_bend)) return false;
    if (out.trace_bend < 0) return false;
    if (!input.read_f64(out.trace_gap)) return false;
    if (out.trace_gap < 0) return false;
    if (!input.read_f64(out.trace_length)) return false;
    if (out.trace_length < 0) return false;
    if (!input.read_f64(out.trace_speed)) return false;
    if (out.trace_speed < 0) return false;
    if (!input.read_f64(out.arrow_radius)) return false;
    if (out.arrow_radius < 0) return false;
    if (!input.read_f64(out.arrow_length)) return false;
    if (out.arrow_length < 0) return false;
    if (!input.read_u32(out.projectile)) return false;
    return true;
}
struct CentaurusPowerDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t count{};
    double alert{};
    double radius{};
    double travel{};
    double spread{};
    uint32_t projectile{};
};
inline bool read(BinaryReader &input, CentaurusPowerDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 1) return false;
    if (!input.read_f64(out.alert)) return false;
    if (out.alert < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.travel)) return false;
    if (out.travel < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_u32(out.projectile)) return false;
    return true;
}
struct CentaurusStompDefinition {
    uint32_t id{};
    uint32_t technique{};
    double radius{};
    double half_angle{};
};
inline bool read(BinaryReader &input, CentaurusStompDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.half_angle)) return false;
    if (out.half_angle < 0) return false;
    return true;
}
struct CentaurusStompFoot {
    uint32_t id{};
    uint32_t technique{};
    uint32_t frame{};
    uint32_t leg{};
    double duration{};
    bool interpolate{};
    bool pivot{};
    double x{};
    double y{};
    double scale_x{};
    double scale_y{};
    double rotation{};
    double skew{};
    double pivot_x{};
    double pivot_y{};
    double origin_x{};
    double origin_y{};
    double contact_x{};
    double contact_y{};
};
inline bool read(BinaryReader &input, CentaurusStompFoot &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.frame)) return false;
    if (!input.read_u32(out.leg)) return false;
    if (out.leg > 1) return false;
    if (!input.read_f64(out.duration)) return false;
    if (out.duration < 0.02) return false;
    if (!input.read_bool(out.interpolate)) return false;
    if (!input.read_bool(out.pivot)) return false;
    if (!input.read_f64(out.x)) return false;
    if (!input.read_f64(out.y)) return false;
    if (!input.read_f64(out.scale_x)) return false;
    if (!input.read_f64(out.scale_y)) return false;
    if (!input.read_f64(out.rotation)) return false;
    if (!input.read_f64(out.skew)) return false;
    if (!input.read_f64(out.pivot_x)) return false;
    if (!input.read_f64(out.pivot_y)) return false;
    if (!input.read_f64(out.origin_x)) return false;
    if (!input.read_f64(out.origin_y)) return false;
    if (!input.read_f64(out.contact_x)) return false;
    if (!input.read_f64(out.contact_y)) return false;
    return true;
}
struct CentaurusFanDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t shots{};
    uint32_t count{};
    double interval{};
    double spread{};
    double radius{};
    double length{};
    double travel{};
    uint32_t projectile{};
};
inline bool read(BinaryReader &input, CentaurusFanDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.shots)) return false;
    if (out.shots < 1) return false;
    if (!input.read_u32(out.count)) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.travel)) return false;
    if (out.travel < 0) return false;
    if (!input.read_u32(out.projectile)) return false;
    return true;
}
struct CentaurusShowerDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t pattern{};
    uint32_t count{};
    double mark_time{};
    double rain_time{};
    double linger{};
    double radius{};
    double interval{};
    double lead{};
    double spacing{};
    double step{};
    double wall_ratio{};
    double wall_min{};
    double wall_max{};
    double ahead{};
    double arrow_radius{};
    double arrow_length{};
    uint32_t projectile{};
};
inline bool read(BinaryReader &input, CentaurusShowerDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.pattern)) return false;
    if (out.pattern > 2) return false;
    if (!input.read_u32(out.count)) return false;
    if (!input.read_f64(out.mark_time)) return false;
    if (out.mark_time < 0) return false;
    if (!input.read_f64(out.rain_time)) return false;
    if (out.rain_time < 0) return false;
    if (!input.read_f64(out.linger)) return false;
    if (out.linger < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.lead)) return false;
    if (out.lead < 0) return false;
    if (!input.read_f64(out.spacing)) return false;
    if (out.spacing < 0) return false;
    if (!input.read_f64(out.step)) return false;
    if (out.step < 0) return false;
    if (!input.read_f64(out.wall_ratio)) return false;
    if (out.wall_ratio < 0) return false;
    if (!input.read_f64(out.wall_min)) return false;
    if (out.wall_min < 0) return false;
    if (!input.read_f64(out.wall_max)) return false;
    if (out.wall_max < 0) return false;
    if (!input.read_f64(out.ahead)) return false;
    if (out.ahead < 0) return false;
    if (!input.read_f64(out.arrow_radius)) return false;
    if (out.arrow_radius < 0) return false;
    if (!input.read_f64(out.arrow_length)) return false;
    if (out.arrow_length < 0) return false;
    if (!input.read_u32(out.projectile)) return false;
    return true;
}
struct CentaurusSailDefinition {
    uint32_t id{};
    uint32_t technique{};
    double approach_speed{};
    double radius_min{};
    double radius_max{};
    double arc{};
    double duration{};
    double interval{};
    double radius{};
    double length{};
    double travel{};
    uint32_t projectile{};
};
inline bool read(BinaryReader &input, CentaurusSailDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.approach_speed)) return false;
    if (out.approach_speed < 0) return false;
    if (!input.read_f64(out.radius_min)) return false;
    if (out.radius_min < 0) return false;
    if (!input.read_f64(out.radius_max)) return false;
    if (out.radius_max < 0) return false;
    if (!input.read_f64(out.arc)) return false;
    if (out.arc < 0) return false;
    if (!input.read_f64(out.duration)) return false;
    if (out.duration < 0) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.travel)) return false;
    if (out.travel < 0) return false;
    if (!input.read_u32(out.projectile)) return false;
    return true;
}
struct CentaurusComboDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t first{};
    uint32_t second{};
    double gap{};
};
inline bool read(BinaryReader &input, CentaurusComboDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.first)) return false;
    if (!input.read_u32(out.second)) return false;
    if (!input.read_f64(out.gap)) return false;
    if (out.gap < 0) return false;
    return true;
}
struct CanisBodyDefinition {
    uint32_t id{};
    uint32_t boss{};
    uint32_t hound{};
    double speed_p2{};
    double entrance_bark{};
    double call_time{};
    double call_cd{};
    double lead_radius{};
    double lead_scan{};
    double lead_catch_up{};
    double led_hits{};
    double slot_back{};
    double slot_side{};
    double form_wobble{};
    double lane_open{};
    double lane_forward{};
    double form_speed_min{};
    double form_speed_max{};
    uint32_t pack_size{};
    uint32_t call_below{};
    uint32_t call_to{};
    uint32_t lead_max{};
    float led_r{};
    float led_g{};
    float led_b{};
    float led_a{};
};
inline bool read(BinaryReader &input, CanisBodyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_u32(out.hound)) return false;
    if (!input.read_f64(out.speed_p2)) return false;
    if (out.speed_p2 < 0) return false;
    if (!input.read_f64(out.entrance_bark)) return false;
    if (out.entrance_bark < 0) return false;
    if (!input.read_f64(out.call_time)) return false;
    if (out.call_time < 0) return false;
    if (!input.read_f64(out.call_cd)) return false;
    if (out.call_cd < 0) return false;
    if (!input.read_f64(out.lead_radius)) return false;
    if (out.lead_radius < 0) return false;
    if (!input.read_f64(out.lead_scan)) return false;
    if (out.lead_scan < 0) return false;
    if (!input.read_f64(out.lead_catch_up)) return false;
    if (out.lead_catch_up < 0) return false;
    if (!input.read_f64(out.led_hits)) return false;
    if (out.led_hits < 0) return false;
    if (!input.read_f64(out.slot_back)) return false;
    if (out.slot_back < 0) return false;
    if (!input.read_f64(out.slot_side)) return false;
    if (out.slot_side < 0) return false;
    if (!input.read_f64(out.form_wobble)) return false;
    if (out.form_wobble < 0) return false;
    if (!input.read_f64(out.lane_open)) return false;
    if (out.lane_open < 0) return false;
    if (!input.read_f64(out.lane_forward)) return false;
    if (out.lane_forward < 0) return false;
    if (!input.read_f64(out.form_speed_min)) return false;
    if (out.form_speed_min < 0) return false;
    if (!input.read_f64(out.form_speed_max)) return false;
    if (out.form_speed_max < 0) return false;
    if (!input.read_u32(out.pack_size)) return false;
    if (!input.read_u32(out.call_below)) return false;
    if (!input.read_u32(out.call_to)) return false;
    if (!input.read_u32(out.lead_max)) return false;
    if (!input.read_f32(out.led_r)) return false;
    if (!input.read_f32(out.led_g)) return false;
    if (!input.read_f32(out.led_b)) return false;
    if (!input.read_f32(out.led_a)) return false;
    return true;
}
struct CanisFlameDefinition {
    uint32_t id{};
    uint32_t boss{};
    std::string external_id{};
    uint32_t phase{};
    uint32_t kind{};
    double particle_life{};
    double length{};
    double width{};
    double duration{};
    double damage{};
    double spread{};
    double speed{};
    double drag{};
    double r_start{};
    double r_end{};
    double hit_scale{};
    double trail_delay{};
    double trail_life{};
    double trail_width{};
    double trail_damage{};
};
inline bool read(BinaryReader &input, CanisFlameDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_string(out.external_id)) return false;
    if (!input.read_u32(out.phase)) return false;
    if (out.phase < 1) return false;
    if (out.phase > 2) return false;
    if (!input.read_u32(out.kind)) return false;
    if (out.kind > 2) return false;
    if (!input.read_f64(out.particle_life)) return false;
    if (out.particle_life < 0) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.duration)) return false;
    if (out.duration < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.drag)) return false;
    if (out.drag < 0) return false;
    if (!input.read_f64(out.r_start)) return false;
    if (out.r_start < 0) return false;
    if (!input.read_f64(out.r_end)) return false;
    if (out.r_end < 0) return false;
    if (!input.read_f64(out.hit_scale)) return false;
    if (out.hit_scale < 0) return false;
    if (!input.read_f64(out.trail_delay)) return false;
    if (out.trail_delay < 0) return false;
    if (!input.read_f64(out.trail_life)) return false;
    if (out.trail_life < 0) return false;
    if (!input.read_f64(out.trail_width)) return false;
    if (out.trail_width < 0) return false;
    if (!input.read_f64(out.trail_damage)) return false;
    if (out.trail_damage < 0) return false;
    return true;
}
struct CanisCommandDefinition {
    uint32_t id{};
    uint32_t technique{};
    double lunge_speed{};
    double lunge_time{};
    uint32_t min_hounds{};
};
inline bool read(BinaryReader &input, CanisCommandDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.lunge_speed)) return false;
    if (out.lunge_speed < 0) return false;
    if (!input.read_f64(out.lunge_time)) return false;
    if (out.lunge_time < 0) return false;
    if (!input.read_u32(out.min_hounds)) return false;
    return true;
}
struct CanisHowlDefinition {
    uint32_t id{};
    uint32_t technique{};
    double catch_up{};
    double close_time{};
    uint32_t gap_slots{};
    uint32_t gaps{};
    double gather_time{};
    double ring_close{};
    uint32_t ring_count{};
    double ring_radius{};
    double spawn_out{};
    uint32_t summon_max{};
    double follow_time{};
    double follow_rate{};
    double seq_interval{};
    double seq_warn{};
    double lunge_speed{};
    double lunge_time{};
    double tail{};
};
inline bool read(BinaryReader &input, CanisHowlDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.catch_up)) return false;
    if (out.catch_up < 0) return false;
    if (!input.read_f64(out.close_time)) return false;
    if (out.close_time < 0) return false;
    if (!input.read_u32(out.gap_slots)) return false;
    if (out.gap_slots < 0) return false;
    if (!input.read_u32(out.gaps)) return false;
    if (out.gaps < 0) return false;
    if (!input.read_f64(out.gather_time)) return false;
    if (out.gather_time < 0) return false;
    if (!input.read_f64(out.ring_close)) return false;
    if (out.ring_close < 0) return false;
    if (!input.read_u32(out.ring_count)) return false;
    if (out.ring_count < 0) return false;
    if (!input.read_f64(out.ring_radius)) return false;
    if (out.ring_radius < 0) return false;
    if (!input.read_f64(out.spawn_out)) return false;
    if (out.spawn_out < 0) return false;
    if (!input.read_u32(out.summon_max)) return false;
    if (out.summon_max < 0) return false;
    if (!input.read_f64(out.follow_time)) return false;
    if (out.follow_time < 0) return false;
    if (!input.read_f64(out.follow_rate)) return false;
    if (out.follow_rate < 0) return false;
    if (!input.read_f64(out.seq_interval)) return false;
    if (out.seq_interval < 0) return false;
    if (!input.read_f64(out.seq_warn)) return false;
    if (out.seq_warn < 0) return false;
    if (!input.read_f64(out.lunge_speed)) return false;
    if (out.lunge_speed < 0) return false;
    if (!input.read_f64(out.lunge_time)) return false;
    if (out.lunge_time < 0) return false;
    if (!input.read_f64(out.tail)) return false;
    if (out.tail < 0) return false;
    return true;
}
struct CanisPounceDefinition {
    uint32_t id{};
    uint32_t technique{};
    double active{};
    uint32_t alone_hounds{};
    double cd_alone{};
    double lock{};
    double overshoot{};
    double lead_extra{};
    uint32_t chain{};
    double chain_warn{};
};
inline bool read(BinaryReader &input, CanisPounceDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.active)) return false;
    if (out.active < 0) return false;
    if (!input.read_u32(out.alone_hounds)) return false;
    if (out.alone_hounds < 0) return false;
    if (!input.read_f64(out.cd_alone)) return false;
    if (out.cd_alone < 0) return false;
    if (!input.read_f64(out.lock)) return false;
    if (out.lock < 0) return false;
    if (!input.read_f64(out.overshoot)) return false;
    if (out.overshoot < 0) return false;
    if (!input.read_f64(out.lead_extra)) return false;
    if (out.lead_extra < 0) return false;
    if (!input.read_u32(out.chain)) return false;
    if (out.chain < 0) return false;
    if (!input.read_f64(out.chain_warn)) return false;
    if (out.chain_warn < 0) return false;
    return true;
}
struct CanisSiriusDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t flame{};
    uint32_t shots{};
    double shot_gap{};
    double lock{};
    double lead{};
    double aim_turn{};
};
inline bool read(BinaryReader &input, CanisSiriusDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.flame)) return false;
    if (!input.read_u32(out.shots)) return false;
    if (out.shots < 0) return false;
    if (!input.read_f64(out.shot_gap)) return false;
    if (out.shot_gap < 0) return false;
    if (!input.read_f64(out.lock)) return false;
    if (out.lock < 0) return false;
    if (!input.read_f64(out.lead)) return false;
    if (out.lead < 0) return false;
    if (!input.read_f64(out.aim_turn)) return false;
    if (out.aim_turn < 0) return false;
    return true;
}
struct CanisBayDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t pounce{};
    uint32_t count{};
    uint32_t min_hounds{};
    double pounce_at{};
    double approach_stop{};
    double orbit{};
    double r_front{};
    double r_side{};
    double r_back{};
    double front_angle{};
    double back_angle{};
    double wobble{};
    double max_speed{};
    double turn_fast{};
    double turn_slow{};
    double turn_switch{};
    double accel{};
    double decel{};
    double arrive{};
    double face_turn{};
    double bark_min{};
    double bark_max{};
    uint32_t nip_max{};
    double nip_warn{};
    double nip_speed{};
    double nip_time{};
    double nip_after_speed{};
    double nip_cd{};
    double nip_damage{};
};
inline bool read(BinaryReader &input, CanisBayDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.pounce)) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 0) return false;
    if (!input.read_u32(out.min_hounds)) return false;
    if (out.min_hounds < 0) return false;
    if (!input.read_f64(out.pounce_at)) return false;
    if (out.pounce_at < 0) return false;
    if (!input.read_f64(out.approach_stop)) return false;
    if (out.approach_stop < 0) return false;
    if (!input.read_f64(out.orbit)) return false;
    if (out.orbit < 0) return false;
    if (!input.read_f64(out.r_front)) return false;
    if (out.r_front < 0) return false;
    if (!input.read_f64(out.r_side)) return false;
    if (out.r_side < 0) return false;
    if (!input.read_f64(out.r_back)) return false;
    if (out.r_back < 0) return false;
    if (!input.read_f64(out.front_angle)) return false;
    if (out.front_angle < 0) return false;
    if (!input.read_f64(out.back_angle)) return false;
    if (out.back_angle < 0) return false;
    if (!input.read_f64(out.wobble)) return false;
    if (out.wobble < 0) return false;
    if (!input.read_f64(out.max_speed)) return false;
    if (out.max_speed < 0) return false;
    if (!input.read_f64(out.turn_fast)) return false;
    if (out.turn_fast < 0) return false;
    if (!input.read_f64(out.turn_slow)) return false;
    if (out.turn_slow < 0) return false;
    if (!input.read_f64(out.turn_switch)) return false;
    if (out.turn_switch < 0) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.decel)) return false;
    if (out.decel < 0) return false;
    if (!input.read_f64(out.arrive)) return false;
    if (out.arrive < 0) return false;
    if (!input.read_f64(out.face_turn)) return false;
    if (out.face_turn < 0) return false;
    if (!input.read_f64(out.bark_min)) return false;
    if (out.bark_min < 0) return false;
    if (!input.read_f64(out.bark_max)) return false;
    if (out.bark_max < 0) return false;
    if (!input.read_u32(out.nip_max)) return false;
    if (out.nip_max < 0) return false;
    if (!input.read_f64(out.nip_warn)) return false;
    if (out.nip_warn < 0) return false;
    if (!input.read_f64(out.nip_speed)) return false;
    if (out.nip_speed < 0) return false;
    if (!input.read_f64(out.nip_time)) return false;
    if (out.nip_time < 0) return false;
    if (!input.read_f64(out.nip_after_speed)) return false;
    if (out.nip_after_speed < 0) return false;
    if (!input.read_f64(out.nip_cd)) return false;
    if (out.nip_cd < 0) return false;
    if (!input.read_f64(out.nip_damage)) return false;
    if (out.nip_damage < 0) return false;
    return true;
}
struct CanisBlazeDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t flame{};
    uint32_t count{};
    uint32_t min_hounds{};
    double ignite_at{};
    double ignite_step{};
    double run_speed{};
    double stop_dist{};
    double max_run{};
    double blink{};
    double explode_radius{};
    double arrive{};
    double decel{};
    double face_turn{};
    double turn_slow{};
    double turn_fast{};
    double turn_switch{};
    double accel{};
};
inline bool read(BinaryReader &input, CanisBlazeDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.flame)) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 0) return false;
    if (!input.read_u32(out.min_hounds)) return false;
    if (out.min_hounds < 0) return false;
    if (!input.read_f64(out.ignite_at)) return false;
    if (out.ignite_at < 0) return false;
    if (!input.read_f64(out.ignite_step)) return false;
    if (out.ignite_step < 0) return false;
    if (!input.read_f64(out.run_speed)) return false;
    if (out.run_speed < 0) return false;
    if (!input.read_f64(out.stop_dist)) return false;
    if (out.stop_dist < 0) return false;
    if (!input.read_f64(out.max_run)) return false;
    if (out.max_run < 0) return false;
    if (!input.read_f64(out.blink)) return false;
    if (out.blink < 0) return false;
    if (!input.read_f64(out.explode_radius)) return false;
    if (out.explode_radius < 0) return false;
    if (!input.read_f64(out.arrive)) return false;
    if (out.arrive < 0) return false;
    if (!input.read_f64(out.decel)) return false;
    if (out.decel < 0) return false;
    if (!input.read_f64(out.face_turn)) return false;
    if (out.face_turn < 0) return false;
    if (!input.read_f64(out.turn_slow)) return false;
    if (out.turn_slow < 0) return false;
    if (!input.read_f64(out.turn_fast)) return false;
    if (out.turn_fast < 0) return false;
    if (!input.read_f64(out.turn_switch)) return false;
    if (out.turn_switch < 0) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    return true;
}
struct CanisStreamDefinition {
    uint32_t id{};
    uint32_t technique{};
    double interval{};
    double each_warn{};
    double lunge_speed{};
    double lunge_time{};
    uint32_t min_hounds{};
};
inline bool read(BinaryReader &input, CanisStreamDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.each_warn)) return false;
    if (out.each_warn < 0) return false;
    if (!input.read_f64(out.lunge_speed)) return false;
    if (out.lunge_speed < 0) return false;
    if (!input.read_f64(out.lunge_time)) return false;
    if (out.lunge_time < 0) return false;
    if (!input.read_u32(out.min_hounds)) return false;
    if (out.min_hounds < 0) return false;
    return true;
}
struct CanisHuntDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t stream{};
    uint32_t flame{};
    uint32_t min_hounds{};
    double gap{};
    double aim_warn{};
    double aim_lock{};
    double aim_lead{};
    double aim_turn{};
};
inline bool read(BinaryReader &input, CanisHuntDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.stream)) return false;
    if (!input.read_u32(out.flame)) return false;
    if (!input.read_u32(out.min_hounds)) return false;
    if (!input.read_f64(out.gap)) return false;
    if (out.gap < 0) return false;
    if (!input.read_f64(out.aim_warn)) return false;
    if (out.aim_warn < 0) return false;
    if (!input.read_f64(out.aim_lock)) return false;
    if (out.aim_lock < 0) return false;
    if (!input.read_f64(out.aim_lead)) return false;
    if (out.aim_lead < 0) return false;
    if (!input.read_f64(out.aim_turn)) return false;
    if (out.aim_turn < 0) return false;
    return true;
}
struct CanisHuntPounceDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t stream{};
    uint32_t pounce{};
    double gap{};
};
inline bool read(BinaryReader &input, CanisHuntPounceDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.stream)) return false;
    if (!input.read_u32(out.pounce)) return false;
    if (!input.read_f64(out.gap)) return false;
    if (out.gap < 0) return false;
    return true;
}
struct CanisNovaDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t count{};
    uint32_t min_hounds{};
    uint32_t rings{};
    double pair_dist{};
    double pair_side{};
    double gather_speed{};
    double body_radius{};
    double ring_gap{};
    double ring_speed{};
    double ring_band{};
    double ring_end{};
    double after{};
    double arrive{};
    double decel{};
    double face_turn{};
    double turn_slow{};
    double turn_fast{};
    double turn_switch{};
    double accel{};
};
inline bool read(BinaryReader &input, CanisNovaDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 0) return false;
    if (!input.read_u32(out.min_hounds)) return false;
    if (out.min_hounds < 0) return false;
    if (!input.read_u32(out.rings)) return false;
    if (out.rings < 0) return false;
    if (!input.read_f64(out.pair_dist)) return false;
    if (out.pair_dist < 0) return false;
    if (!input.read_f64(out.pair_side)) return false;
    if (out.pair_side < 0) return false;
    if (!input.read_f64(out.gather_speed)) return false;
    if (out.gather_speed < 0) return false;
    if (!input.read_f64(out.body_radius)) return false;
    if (out.body_radius < 0) return false;
    if (!input.read_f64(out.ring_gap)) return false;
    if (out.ring_gap < 0) return false;
    if (!input.read_f64(out.ring_speed)) return false;
    if (out.ring_speed < 0) return false;
    if (!input.read_f64(out.ring_band)) return false;
    if (out.ring_band < 0) return false;
    if (!input.read_f64(out.ring_end)) return false;
    if (out.ring_end < 0) return false;
    if (!input.read_f64(out.after)) return false;
    if (out.after < 0) return false;
    if (!input.read_f64(out.arrive)) return false;
    if (out.arrive < 0) return false;
    if (!input.read_f64(out.decel)) return false;
    if (out.decel < 0) return false;
    if (!input.read_f64(out.face_turn)) return false;
    if (out.face_turn < 0) return false;
    if (!input.read_f64(out.turn_slow)) return false;
    if (out.turn_slow < 0) return false;
    if (!input.read_f64(out.turn_fast)) return false;
    if (out.turn_fast < 0) return false;
    if (!input.read_f64(out.turn_switch)) return false;
    if (out.turn_switch < 0) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    return true;
}
struct CanisRelayDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t hound_flame{};
    uint32_t final_flame{};
    uint32_t min_hounds{};
    double interval{};
    double each_warn{};
    double final_warn{};
    double final_lock{};
    double final_turn{};
};
inline bool read(BinaryReader &input, CanisRelayDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.hound_flame)) return false;
    if (!input.read_u32(out.final_flame)) return false;
    if (!input.read_u32(out.min_hounds)) return false;
    if (out.min_hounds < 0) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.each_warn)) return false;
    if (out.each_warn < 0) return false;
    if (!input.read_f64(out.final_warn)) return false;
    if (out.final_warn < 0) return false;
    if (!input.read_f64(out.final_lock)) return false;
    if (out.final_lock < 0) return false;
    if (!input.read_f64(out.final_turn)) return false;
    if (out.final_turn < 0) return false;
    return true;
}
struct CanisSiriusFlameDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t flame{};
    double emit_rate{};
    double turn{};
    double advance{};
    double advance_until{};
};
inline bool read(BinaryReader &input, CanisSiriusFlameDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.flame)) return false;
    if (!input.read_f64(out.emit_rate)) return false;
    if (out.emit_rate < 0) return false;
    if (!input.read_f64(out.turn)) return false;
    if (out.turn < 0) return false;
    if (!input.read_f64(out.advance)) return false;
    if (out.advance < 0) return false;
    if (!input.read_f64(out.advance_until)) return false;
    if (out.advance_until < 0) return false;
    return true;
}
struct HydraBodyDefinition {
    uint32_t id{};
    uint32_t boss{};
    uint32_t bite{};
    uint32_t vortex{};
    uint32_t debris{};
    uint32_t beam{};
    uint32_t thunder{};
    double accel{};
    double engage{};
    double neck_rest{};
    double head_hp{};
    double attack_cd{};
    double aim_refresh{};
    double aim_deadzone{};
    double aim_accel{};
    double aim_turn{};
    double neck_slack{};
    double neck_wave_amplitude{};
    double neck_wave_frequency{};
    double neck_wave_speed{};
    double neck_response{};
    double arena_x{};
    double arena_y{};
    double arena_wall_thickness{};
    uint32_t neck_segments{};
    uint32_t neck_iterations{};
};
inline bool read(BinaryReader &input, HydraBodyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_u32(out.bite)) return false;
    if (!input.read_u32(out.vortex)) return false;
    if (!input.read_u32(out.debris)) return false;
    if (!input.read_u32(out.beam)) return false;
    if (!input.read_u32(out.thunder)) return false;
    if (!input.read_f64(out.accel)) return false;
    if (out.accel < 0) return false;
    if (!input.read_f64(out.engage)) return false;
    if (out.engage < 0) return false;
    if (!input.read_f64(out.neck_rest)) return false;
    if (out.neck_rest < 0) return false;
    if (!input.read_f64(out.head_hp)) return false;
    if (out.head_hp < 0) return false;
    if (!input.read_f64(out.attack_cd)) return false;
    if (out.attack_cd < 0) return false;
    if (!input.read_f64(out.aim_refresh)) return false;
    if (out.aim_refresh < 0) return false;
    if (!input.read_f64(out.aim_deadzone)) return false;
    if (out.aim_deadzone < 0) return false;
    if (!input.read_f64(out.aim_accel)) return false;
    if (out.aim_accel < 0) return false;
    if (!input.read_f64(out.aim_turn)) return false;
    if (out.aim_turn < 0) return false;
    if (!input.read_f64(out.neck_slack)) return false;
    if (out.neck_slack < 0) return false;
    if (!input.read_f64(out.neck_wave_amplitude)) return false;
    if (out.neck_wave_amplitude < 0) return false;
    if (!input.read_f64(out.neck_wave_frequency)) return false;
    if (out.neck_wave_frequency < 0) return false;
    if (!input.read_f64(out.neck_wave_speed)) return false;
    if (out.neck_wave_speed < 0) return false;
    if (!input.read_f64(out.neck_response)) return false;
    if (out.neck_response < 0) return false;
    if (!input.read_f64(out.arena_x)) return false;
    if (out.arena_x < 0) return false;
    if (!input.read_f64(out.arena_y)) return false;
    if (out.arena_y < 0) return false;
    if (!input.read_f64(out.arena_wall_thickness)) return false;
    if (out.arena_wall_thickness < 0) return false;
    if (!input.read_u32(out.neck_segments)) return false;
    if (out.neck_segments < 1) return false;
    if (!input.read_u32(out.neck_iterations)) return false;
    if (out.neck_iterations < 1) return false;
    return true;
}
struct HydraRegrowDefinition {
    uint32_t id{};
    uint32_t boss{};
    double regrow{};
    double regrow_per_head{};
    double regrow_combo{};
    double fire_regrow_scale{};
    double chance_time{};
    double growth_time{};
    double growth_first{};
    double growth_second{};
    double debris_dmg{};
};
inline bool read(BinaryReader &input, HydraRegrowDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_f64(out.regrow)) return false;
    if (out.regrow < 0) return false;
    if (!input.read_f64(out.regrow_per_head)) return false;
    if (out.regrow_per_head < 0) return false;
    if (!input.read_f64(out.regrow_combo)) return false;
    if (out.regrow_combo < 0) return false;
    if (!input.read_f64(out.fire_regrow_scale)) return false;
    if (out.fire_regrow_scale < 0) return false;
    if (!input.read_f64(out.chance_time)) return false;
    if (out.chance_time < 0) return false;
    if (!input.read_f64(out.growth_time)) return false;
    if (out.growth_time < 0) return false;
    if (!input.read_f64(out.growth_first)) return false;
    if (out.growth_first < 0) return false;
    if (!input.read_f64(out.growth_second)) return false;
    if (out.growth_second < 0) return false;
    if (!input.read_f64(out.debris_dmg)) return false;
    if (out.debris_dmg < 0) return false;
    return true;
}
struct HydraNormalDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t head_kind{};
    double aim_tracking{};
    double attack_cd{};
    double bite_radius{};
    double cost{};
};
inline bool read(BinaryReader &input, HydraNormalDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.head_kind)) return false;
    if (out.head_kind > 4) return false;
    if (!input.read_f64(out.aim_tracking)) return false;
    if (out.aim_tracking < 0) return false;
    if (!input.read_f64(out.attack_cd)) return false;
    if (out.attack_cd < 0) return false;
    if (!input.read_f64(out.bite_radius)) return false;
    if (out.bite_radius < 0) return false;
    if (!input.read_f64(out.cost)) return false;
    if (out.cost < 0) return false;
    return true;
}
struct HydraSwimDefinition {
    uint32_t id{};
    uint32_t boss{};
    uint32_t immortal{};
    double separation_time{};
    double immortal_hp{};
    double snake_speed{};
    double snake_turn{};
    double snake_accel{};
    double bearer_speed{};
    double solo_bearer_distance{};
    double look_player_turn{};
    double attack_speed{};
    double lunge_momentum{};
};
inline bool read(BinaryReader &input, HydraSwimDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_u32(out.immortal)) return false;
    if (!input.read_f64(out.separation_time)) return false;
    if (out.separation_time < 0) return false;
    if (!input.read_f64(out.immortal_hp)) return false;
    if (out.immortal_hp < 0) return false;
    if (!input.read_f64(out.snake_speed)) return false;
    if (out.snake_speed < 0) return false;
    if (!input.read_f64(out.snake_turn)) return false;
    if (out.snake_turn < 0) return false;
    if (!input.read_f64(out.snake_accel)) return false;
    if (out.snake_accel < 0) return false;
    if (!input.read_f64(out.bearer_speed)) return false;
    if (out.bearer_speed < 0) return false;
    if (!input.read_f64(out.solo_bearer_distance)) return false;
    if (out.solo_bearer_distance < 0) return false;
    if (!input.read_f64(out.look_player_turn)) return false;
    if (out.look_player_turn < 0) return false;
    if (!input.read_f64(out.attack_speed)) return false;
    if (out.attack_speed < 0) return false;
    if (!input.read_f64(out.lunge_momentum)) return false;
    if (out.lunge_momentum < 0) return false;
    return true;
}
struct HydraNormalGate {
    uint32_t id{};
    uint32_t technique{};
    double minimum{};
    double maximum{};
    double angle{};
    double half_angle{};
    uint32_t distance_origin{};
    uint32_t angle_origin{};
    bool ignore_when_separated{};
};
inline bool read(BinaryReader &input, HydraNormalGate &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.minimum)) return false;
    if (out.minimum < 0) return false;
    if (!input.read_f64(out.maximum)) return false;
    if (out.maximum < 0) return false;
    if (!input.read_f64(out.angle)) return false;
    if (!input.read_f64(out.half_angle)) return false;
    if (!input.read_u32(out.distance_origin)) return false;
    if (out.distance_origin > 2) return false;
    if (!input.read_u32(out.angle_origin)) return false;
    if (out.angle_origin > 1) return false;
    if (!input.read_bool(out.ignore_when_separated)) return false;
    return true;
}
struct HydraSquadDefinition {
    uint32_t id{};
    uint32_t boss{};
    double counter_max{};
    double counter_gap{};
    double counter_sight{};
    double counter_range_cap{};
    double counter_extra{};
    double pincer_weight{};
    double wave_weight{};
    double wall_weight{};
    double wall_near_weight{};
    double repeat_weight{};
    double wall_time_x{};
    double wall_time_y{};
    double tactic_time_x{};
    double tactic_time_y{};
    double pincer_velocity{};
    double pincer_idle_noise{};
    double pincer_noise{};
    double attack_arrival{};
    double pincer_timeout{};
    double pincer_gap_x{};
    double pincer_gap_y{};
    double initial_gap_x{};
    double initial_gap_y{};
    double wave_candidates{};
    double wave_repeat_weight{};
    double wave_separation{};
    double wave_timeout{};
    double wave_gap_x{};
    double wave_gap_y{};
    double pick_band{};
    double pick_distance{};
    double pick_rest{};
    double pick_front_weight{};
    double pick_front_distance{};
    double lunge_momentum{};
    double look_forward_noise{};
    double look_forward_turn{};
    double look_player_turn{};
    double look_wave{};
    double look_wave_speed{};
    double look_near_extra{};
    double alignment_cap{};
    double alignment_weight{};
    double arrival{};
    double arrival_drift{};
    double arrival_drift_distance{};
    double attack_speed{};
    double avoid_reduction{};
    double bearer_arrival{};
    double bearer_band_x{};
    double bearer_band_y{};
    double bearer_drift{};
    double bearer_near_speed{};
    double bearer_panic_speed{};
    double bearer_radius{};
    double bearer_replan{};
    double bearer_ring{};
    double bearer_speed{};
    double bearer_turn{};
    double bearer_wall_band_x{};
    double bearer_wall_band_y{};
    double block_arrival{};
    double block_count{};
    double block_distance{};
    double block_force_cap{};
    double block_fraction{};
    double block_predict{};
    double block_response{};
    double block_separation{};
    double block_speed{};
    double block_spread{};
    double block_turn{};
    double body_length{};
    double body_radius{};
    double body_step{};
    double body_weight{};
    double chase_extra{};
    double close_angles_0{};
    double close_angles_1{};
    double close_angles_2{};
    double close_angles_3{};
    double close_radii_0{};
    double close_radii_1{};
    double close_sight{};
    double close_speed{};
    double cohesion_cap{};
    double cohesion_weight{};
    double detour_radius{};
    double detour_seek{};
    double far_distance{};
    double far_speed{};
    double flee_candidates{};
    double flee_distance_weight{};
    double flee_far_weight{};
    double flee_guard_weight{};
    double flee_margin{};
    double flee_noise{};
    double flee_view_weight{};
    double flee_wall_weight{};
    double force_cap{};
    double front_count{};
    double front_fraction{};
    double front_loyalty{};
    double front_near_count{};
    double front_outer{};
    double front_pick_distance{};
    double front_radius_x{};
    double front_radius_y{};
    double front_sight{};
    double front_spacing{};
    double front_speed{};
    double front_spread{};
    double front_spread_max{};
    double gain{};
    double goal_response{};
    double neighbor_radius{};
    double neighbor_soft{};
    double panic_cooldown{};
    double panic_distance{};
    double panic_radius{};
    double panic_time{};
    double predict{};
    double reorient{};
    double reorient_gap{};
    double replan_x{};
    double replan_y{};
    double seek_cap{};
    double separation_cap{};
    double separation_radius{};
    double separation_tau{};
    double separation_weight{};
    double sight_distance{};
    double sight_floor{};
    double slot_margin{};
    double turn{};
    double urgency{};
    double velocity_cap{};
    double velocity_floor{};
    double view_margin_x{};
    double view_margin_y{};
    double wall_max{};
    double wall_spread{};
    double busy_windup{};
    double busy_active{};
    double busy_hold{};
    double look_attack_on_x{};
    double look_attack_on_y{};
    double look_attack_off_x{};
    double look_attack_off_y{};
    double look_attack_limit{};
    double look_front_on_x{};
    double look_front_on_y{};
    double look_front_off_x{};
    double look_front_off_y{};
    double look_front_limit{};
    double look_close_on_x{};
    double look_close_on_y{};
    double look_close_off_x{};
    double look_close_off_y{};
    double look_close_limit{};
    double look_block_on_x{};
    double look_block_on_y{};
    double look_block_off_x{};
    double look_block_off_y{};
    double look_block_limit{};
    double look_bearer_on_x{};
    double look_bearer_on_y{};
    double look_bearer_off_x{};
    double look_bearer_off_y{};
    double look_bearer_limit{};
    double range_bite{};
    double range_thunder{};
    double range_vortex{};
    double range_debris{};
    double range_beam{};
};
inline bool read(BinaryReader &input, HydraSquadDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_f64(out.counter_max)) return false;
    if (!input.read_f64(out.counter_gap)) return false;
    if (!input.read_f64(out.counter_sight)) return false;
    if (!input.read_f64(out.counter_range_cap)) return false;
    if (!input.read_f64(out.counter_extra)) return false;
    if (!input.read_f64(out.pincer_weight)) return false;
    if (!input.read_f64(out.wave_weight)) return false;
    if (!input.read_f64(out.wall_weight)) return false;
    if (!input.read_f64(out.wall_near_weight)) return false;
    if (!input.read_f64(out.repeat_weight)) return false;
    if (!input.read_f64(out.wall_time_x)) return false;
    if (!input.read_f64(out.wall_time_y)) return false;
    if (!input.read_f64(out.tactic_time_x)) return false;
    if (!input.read_f64(out.tactic_time_y)) return false;
    if (!input.read_f64(out.pincer_velocity)) return false;
    if (!input.read_f64(out.pincer_idle_noise)) return false;
    if (!input.read_f64(out.pincer_noise)) return false;
    if (!input.read_f64(out.attack_arrival)) return false;
    if (!input.read_f64(out.pincer_timeout)) return false;
    if (!input.read_f64(out.pincer_gap_x)) return false;
    if (!input.read_f64(out.pincer_gap_y)) return false;
    if (!input.read_f64(out.initial_gap_x)) return false;
    if (!input.read_f64(out.initial_gap_y)) return false;
    if (!input.read_f64(out.wave_candidates)) return false;
    if (!input.read_f64(out.wave_repeat_weight)) return false;
    if (!input.read_f64(out.wave_separation)) return false;
    if (!input.read_f64(out.wave_timeout)) return false;
    if (!input.read_f64(out.wave_gap_x)) return false;
    if (!input.read_f64(out.wave_gap_y)) return false;
    if (!input.read_f64(out.pick_band)) return false;
    if (!input.read_f64(out.pick_distance)) return false;
    if (!input.read_f64(out.pick_rest)) return false;
    if (!input.read_f64(out.pick_front_weight)) return false;
    if (!input.read_f64(out.pick_front_distance)) return false;
    if (!input.read_f64(out.lunge_momentum)) return false;
    if (!input.read_f64(out.look_forward_noise)) return false;
    if (!input.read_f64(out.look_forward_turn)) return false;
    if (!input.read_f64(out.look_player_turn)) return false;
    if (!input.read_f64(out.look_wave)) return false;
    if (!input.read_f64(out.look_wave_speed)) return false;
    if (!input.read_f64(out.look_near_extra)) return false;
    if (!input.read_f64(out.alignment_cap)) return false;
    if (!input.read_f64(out.alignment_weight)) return false;
    if (!input.read_f64(out.arrival)) return false;
    if (!input.read_f64(out.arrival_drift)) return false;
    if (!input.read_f64(out.arrival_drift_distance)) return false;
    if (!input.read_f64(out.attack_speed)) return false;
    if (!input.read_f64(out.avoid_reduction)) return false;
    if (!input.read_f64(out.bearer_arrival)) return false;
    if (!input.read_f64(out.bearer_band_x)) return false;
    if (!input.read_f64(out.bearer_band_y)) return false;
    if (!input.read_f64(out.bearer_drift)) return false;
    if (!input.read_f64(out.bearer_near_speed)) return false;
    if (!input.read_f64(out.bearer_panic_speed)) return false;
    if (!input.read_f64(out.bearer_radius)) return false;
    if (!input.read_f64(out.bearer_replan)) return false;
    if (!input.read_f64(out.bearer_ring)) return false;
    if (!input.read_f64(out.bearer_speed)) return false;
    if (!input.read_f64(out.bearer_turn)) return false;
    if (!input.read_f64(out.bearer_wall_band_x)) return false;
    if (!input.read_f64(out.bearer_wall_band_y)) return false;
    if (!input.read_f64(out.block_arrival)) return false;
    if (!input.read_f64(out.block_count)) return false;
    if (!input.read_f64(out.block_distance)) return false;
    if (!input.read_f64(out.block_force_cap)) return false;
    if (!input.read_f64(out.block_fraction)) return false;
    if (!input.read_f64(out.block_predict)) return false;
    if (!input.read_f64(out.block_response)) return false;
    if (!input.read_f64(out.block_separation)) return false;
    if (!input.read_f64(out.block_speed)) return false;
    if (!input.read_f64(out.block_spread)) return false;
    if (!input.read_f64(out.block_turn)) return false;
    if (!input.read_f64(out.body_length)) return false;
    if (!input.read_f64(out.body_radius)) return false;
    if (!input.read_f64(out.body_step)) return false;
    if (!input.read_f64(out.body_weight)) return false;
    if (!input.read_f64(out.chase_extra)) return false;
    if (!input.read_f64(out.close_angles_0)) return false;
    if (!input.read_f64(out.close_angles_1)) return false;
    if (!input.read_f64(out.close_angles_2)) return false;
    if (!input.read_f64(out.close_angles_3)) return false;
    if (!input.read_f64(out.close_radii_0)) return false;
    if (!input.read_f64(out.close_radii_1)) return false;
    if (!input.read_f64(out.close_sight)) return false;
    if (!input.read_f64(out.close_speed)) return false;
    if (!input.read_f64(out.cohesion_cap)) return false;
    if (!input.read_f64(out.cohesion_weight)) return false;
    if (!input.read_f64(out.detour_radius)) return false;
    if (!input.read_f64(out.detour_seek)) return false;
    if (!input.read_f64(out.far_distance)) return false;
    if (!input.read_f64(out.far_speed)) return false;
    if (!input.read_f64(out.flee_candidates)) return false;
    if (!input.read_f64(out.flee_distance_weight)) return false;
    if (!input.read_f64(out.flee_far_weight)) return false;
    if (!input.read_f64(out.flee_guard_weight)) return false;
    if (!input.read_f64(out.flee_margin)) return false;
    if (!input.read_f64(out.flee_noise)) return false;
    if (!input.read_f64(out.flee_view_weight)) return false;
    if (!input.read_f64(out.flee_wall_weight)) return false;
    if (!input.read_f64(out.force_cap)) return false;
    if (!input.read_f64(out.front_count)) return false;
    if (!input.read_f64(out.front_fraction)) return false;
    if (!input.read_f64(out.front_loyalty)) return false;
    if (!input.read_f64(out.front_near_count)) return false;
    if (!input.read_f64(out.front_outer)) return false;
    if (!input.read_f64(out.front_pick_distance)) return false;
    if (!input.read_f64(out.front_radius_x)) return false;
    if (!input.read_f64(out.front_radius_y)) return false;
    if (!input.read_f64(out.front_sight)) return false;
    if (!input.read_f64(out.front_spacing)) return false;
    if (!input.read_f64(out.front_speed)) return false;
    if (!input.read_f64(out.front_spread)) return false;
    if (!input.read_f64(out.front_spread_max)) return false;
    if (!input.read_f64(out.gain)) return false;
    if (!input.read_f64(out.goal_response)) return false;
    if (!input.read_f64(out.neighbor_radius)) return false;
    if (!input.read_f64(out.neighbor_soft)) return false;
    if (!input.read_f64(out.panic_cooldown)) return false;
    if (!input.read_f64(out.panic_distance)) return false;
    if (!input.read_f64(out.panic_radius)) return false;
    if (!input.read_f64(out.panic_time)) return false;
    if (!input.read_f64(out.predict)) return false;
    if (!input.read_f64(out.reorient)) return false;
    if (!input.read_f64(out.reorient_gap)) return false;
    if (!input.read_f64(out.replan_x)) return false;
    if (!input.read_f64(out.replan_y)) return false;
    if (!input.read_f64(out.seek_cap)) return false;
    if (!input.read_f64(out.separation_cap)) return false;
    if (!input.read_f64(out.separation_radius)) return false;
    if (!input.read_f64(out.separation_tau)) return false;
    if (!input.read_f64(out.separation_weight)) return false;
    if (!input.read_f64(out.sight_distance)) return false;
    if (!input.read_f64(out.sight_floor)) return false;
    if (!input.read_f64(out.slot_margin)) return false;
    if (!input.read_f64(out.turn)) return false;
    if (!input.read_f64(out.urgency)) return false;
    if (!input.read_f64(out.velocity_cap)) return false;
    if (!input.read_f64(out.velocity_floor)) return false;
    if (!input.read_f64(out.view_margin_x)) return false;
    if (!input.read_f64(out.view_margin_y)) return false;
    if (!input.read_f64(out.wall_max)) return false;
    if (!input.read_f64(out.wall_spread)) return false;
    if (!input.read_f64(out.busy_windup)) return false;
    if (!input.read_f64(out.busy_active)) return false;
    if (!input.read_f64(out.busy_hold)) return false;
    if (!input.read_f64(out.look_attack_on_x)) return false;
    if (!input.read_f64(out.look_attack_on_y)) return false;
    if (!input.read_f64(out.look_attack_off_x)) return false;
    if (!input.read_f64(out.look_attack_off_y)) return false;
    if (!input.read_f64(out.look_attack_limit)) return false;
    if (!input.read_f64(out.look_front_on_x)) return false;
    if (!input.read_f64(out.look_front_on_y)) return false;
    if (!input.read_f64(out.look_front_off_x)) return false;
    if (!input.read_f64(out.look_front_off_y)) return false;
    if (!input.read_f64(out.look_front_limit)) return false;
    if (!input.read_f64(out.look_close_on_x)) return false;
    if (!input.read_f64(out.look_close_on_y)) return false;
    if (!input.read_f64(out.look_close_off_x)) return false;
    if (!input.read_f64(out.look_close_off_y)) return false;
    if (!input.read_f64(out.look_close_limit)) return false;
    if (!input.read_f64(out.look_block_on_x)) return false;
    if (!input.read_f64(out.look_block_on_y)) return false;
    if (!input.read_f64(out.look_block_off_x)) return false;
    if (!input.read_f64(out.look_block_off_y)) return false;
    if (!input.read_f64(out.look_block_limit)) return false;
    if (!input.read_f64(out.look_bearer_on_x)) return false;
    if (!input.read_f64(out.look_bearer_on_y)) return false;
    if (!input.read_f64(out.look_bearer_off_x)) return false;
    if (!input.read_f64(out.look_bearer_off_y)) return false;
    if (!input.read_f64(out.look_bearer_limit)) return false;
    if (!input.read_f64(out.range_bite)) return false;
    if (!input.read_f64(out.range_thunder)) return false;
    if (!input.read_f64(out.range_vortex)) return false;
    if (!input.read_f64(out.range_debris)) return false;
    if (!input.read_f64(out.range_beam)) return false;
    return true;
}
struct HydraSweepDefinition {
    uint32_t id{};
    uint32_t technique{};
    double arc{};
    double reach{};
};
inline bool read(BinaryReader &input, HydraSweepDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.arc)) return false;
    if (out.arc < 0) return false;
    if (!input.read_f64(out.reach)) return false;
    if (out.reach < 0) return false;
    return true;
}
struct HydraBoltDefinition {
    uint32_t id{};
    uint32_t technique{};
    double length{};
    double width{};
    double life{};
    double speed{};
};
inline bool read(BinaryReader &input, HydraBoltDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    return true;
}
struct HydraFixedBeamDefinition {
    uint32_t id{};
    uint32_t technique{};
    double length{};
    double width{};
};
inline bool read(BinaryReader &input, HydraFixedBeamDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    return true;
}
struct HydraWindBladesDefinition {
    uint32_t id{};
    uint32_t technique{};
    double interval{};
    double size{};
    double width{};
    double life{};
    double speed{};
    double spread{};
};
inline bool read(BinaryReader &input, HydraWindBladesDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.size)) return false;
    if (out.size < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    return true;
}
struct HydraCurveDefinition {
    uint32_t id{};
    uint32_t technique{};
    double length{};
    double width{};
    double delay{};
    double time{};
    double lag{};
    double turn{};
};
inline bool read(BinaryReader &input, HydraCurveDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.delay)) return false;
    if (out.delay < 0) return false;
    if (!input.read_f64(out.time)) return false;
    if (out.time < 0) return false;
    if (!input.read_f64(out.lag)) return false;
    if (out.lag < 0) return false;
    if (!input.read_f64(out.turn)) return false;
    if (out.turn < 0) return false;
    return true;
}
struct HydraMajorDefinition {
    uint32_t id{};
    uint32_t technique{};
    bool combo{};
    bool timeline_available{};
    double cost{};
    double global_cd{};
    double combo_cd{};
    double major_recovery_padding{};
};
inline bool read(BinaryReader &input, HydraMajorDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_bool(out.combo)) return false;
    if (!input.read_bool(out.timeline_available)) return false;
    if (!input.read_f64(out.cost)) return false;
    if (out.cost < 0) return false;
    if (!input.read_f64(out.global_cd)) return false;
    if (out.global_cd < 0) return false;
    if (!input.read_f64(out.combo_cd)) return false;
    if (out.combo_cd < 0) return false;
    if (!input.read_f64(out.major_recovery_padding)) return false;
    if (out.major_recovery_padding < 0) return false;
    return true;
}
struct HydraGridDefinition {
    uint32_t id{};
    uint32_t technique{};
    double width{};
    double delay{};
    double time{};
    double planning_width{};
    double clearance{};
    double tolerance{};
    double formation_timeout{};
    uint32_t minimum{};
};
inline bool read(BinaryReader &input, HydraGridDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.width)) return false;
    if (!input.read_f64(out.delay)) return false;
    if (!input.read_f64(out.time)) return false;
    if (!input.read_f64(out.planning_width)) return false;
    if (!input.read_f64(out.clearance)) return false;
    if (!input.read_f64(out.tolerance)) return false;
    if (!input.read_f64(out.formation_timeout)) return false;
    if (!input.read_u32(out.minimum)) return false;
    if (out.minimum < 1) return false;
    return true;
}
struct HydraGridLayout {
    uint32_t id{};
    uint32_t technique{};
    std::string name{};
    uint32_t region_mask{};
};
inline bool read(BinaryReader &input, HydraGridLayout &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_string(out.name)) return false;
    if (!input.read_u32(out.region_mask)) return false;
    if (out.region_mask > 31) return false;
    return true;
}
struct HydraGridSlot {
    uint32_t id{};
    uint32_t layout{};
    uint32_t order{};
    double from_x{};
    double from_y{};
    double to_x{};
    double to_y{};
};
inline bool read(BinaryReader &input, HydraGridSlot &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.layout)) return false;
    if (!input.read_u32(out.order)) return false;
    if (!input.read_f64(out.from_x)) return false;
    if (!input.read_f64(out.from_y)) return false;
    if (!input.read_f64(out.to_x)) return false;
    if (!input.read_f64(out.to_y)) return false;
    return true;
}
struct HydraGridPath {
    uint32_t id{};
    uint32_t layout{};
    uint32_t order{};
    double x{};
    double y{};
};
inline bool read(BinaryReader &input, HydraGridPath &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.layout)) return false;
    if (!input.read_u32(out.order)) return false;
    if (!input.read_f64(out.x)) return false;
    if (!input.read_f64(out.y)) return false;
    return true;
}
struct HydraRubbleDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t enemy{};
    double radius{};
    double speed{};
    double life{};
    double spread{};
    uint32_t count{};
};
inline bool read(BinaryReader &input, HydraRubbleDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 0) return false;
    return true;
}
struct HydraPincerDefinition {
    uint32_t id{};
    uint32_t technique{};
    double length{};
    double width{};
    double delay{};
    double time{};
    double open_angle{};
    double close_angle{};
};
inline bool read(BinaryReader &input, HydraPincerDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.delay)) return false;
    if (out.delay < 0) return false;
    if (!input.read_f64(out.time)) return false;
    if (out.time < 0) return false;
    if (!input.read_f64(out.open_angle)) return false;
    if (out.open_angle < 0) return false;
    if (!input.read_f64(out.close_angle)) return false;
    if (out.close_angle < 0) return false;
    return true;
}
struct HydraTornadoDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t enemy{};
    double charge{};
    double life{};
    double speed{};
    double width{};
};
inline bool read(BinaryReader &input, HydraTornadoDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (!input.read_f64(out.charge)) return false;
    if (out.charge < 0) return false;
    if (!input.read_f64(out.life)) return false;
    if (out.life < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    return true;
}
struct HydraShatterDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t enemy{};
    uint32_t count{};
    double length{};
    double width{};
    double shard_damage{};
    double shard_speed{};
    double arc{};
    double deploy{};
    double time{};
};
inline bool read(BinaryReader &input, HydraShatterDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count < 0) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.shard_damage)) return false;
    if (out.shard_damage < 0) return false;
    if (!input.read_f64(out.shard_speed)) return false;
    if (out.shard_speed < 0) return false;
    if (!input.read_f64(out.arc)) return false;
    if (out.arc < 0) return false;
    if (!input.read_f64(out.deploy)) return false;
    if (out.deploy < 0) return false;
    if (!input.read_f64(out.time)) return false;
    if (out.time < 0) return false;
    return true;
}
struct HydraThunderDefinition {
    uint32_t id{};
    uint32_t technique{};
    double radius{};
    double flash{};
    double lock_fraction{};
    double lead{};
    double damage{};
};
inline bool read(BinaryReader &input, HydraThunderDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.flash)) return false;
    if (out.flash < 0) return false;
    if (!input.read_f64(out.lock_fraction)) return false;
    if (out.lock_fraction < 0) return false;
    if (!input.read_f64(out.lead)) return false;
    if (out.lead < 0) return false;
    if (!input.read_f64(out.damage)) return false;
    if (out.damage < 0) return false;
    return true;
}
struct HydraWindBandDefinition {
    uint32_t id{};
    uint32_t technique{};
    double length{};
    double width{};
    double force{};
};
inline bool read(BinaryReader &input, HydraWindBandDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.length)) return false;
    if (out.length < 0) return false;
    if (!input.read_f64(out.width)) return false;
    if (out.width < 0) return false;
    if (!input.read_f64(out.force)) return false;
    if (out.force < 0) return false;
    return true;
}
struct HydraNorthDefinition {
    uint32_t id{};
    uint32_t technique{};
    double radius{};
    double flight{};
    double lock_time{};
    double spread{};
    double half_angle{};
};
inline bool read(BinaryReader &input, HydraNorthDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.flight)) return false;
    if (out.flight < 0) return false;
    if (!input.read_f64(out.lock_time)) return false;
    if (out.lock_time < 0) return false;
    if (!input.read_f64(out.spread)) return false;
    if (out.spread < 0) return false;
    if (!input.read_f64(out.half_angle)) return false;
    if (out.half_angle < 0) return false;
    return true;
}
struct HydraSequenceDefinition {
    uint32_t id{};
    uint32_t technique{};
    double radius{};
    double lunge{};
    double charge{};
    double gap{};
    double half_angle{};
};
inline bool read(BinaryReader &input, HydraSequenceDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.lunge)) return false;
    if (out.lunge < 0) return false;
    if (!input.read_f64(out.charge)) return false;
    if (out.charge < 0) return false;
    if (!input.read_f64(out.gap)) return false;
    if (out.gap < 0) return false;
    if (!input.read_f64(out.half_angle)) return false;
    if (out.half_angle < 0) return false;
    return true;
}
struct HydraSwarmDefinition {
    uint32_t id{};
    uint32_t technique{};
    double radius{};
    double flight{};
    double charge{};
    double gap{};
    double reach{};
    double formation_margin{};
    double formation_timeout{};
    double formation_tolerance{};
};
inline bool read(BinaryReader &input, HydraSwarmDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.flight)) return false;
    if (out.flight < 0) return false;
    if (!input.read_f64(out.charge)) return false;
    if (out.charge < 0) return false;
    if (!input.read_f64(out.gap)) return false;
    if (out.gap < 0) return false;
    if (!input.read_f64(out.reach)) return false;
    if (out.reach < 0) return false;
    if (!input.read_f64(out.formation_margin)) return false;
    if (out.formation_margin < 0) return false;
    if (!input.read_f64(out.formation_timeout)) return false;
    if (out.formation_timeout < 0) return false;
    if (!input.read_f64(out.formation_tolerance)) return false;
    if (out.formation_tolerance < 0) return false;
    return true;
}
struct DracoBodyDefinition {
    uint32_t id{};
    uint32_t boss{};
    double body_length{};
    double body_width{};
    double head_scale{};
    double body_wave{};
    double aim_lead_cap{};
    double approach_distance{};
    double threshold_1{};
    double threshold_2{};
    uint32_t body_segments{};
    double head_radius{};
    double part_hp{};
    double part_armor{};
    double entrance_quiet{};
};
inline bool read(BinaryReader &input, DracoBodyDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_f64(out.body_length)) return false;
    if (out.body_length < 0) return false;
    if (!input.read_f64(out.body_width)) return false;
    if (out.body_width < 0) return false;
    if (!input.read_f64(out.head_scale)) return false;
    if (out.head_scale < 0) return false;
    if (!input.read_f64(out.body_wave)) return false;
    if (out.body_wave < 0) return false;
    if (!input.read_f64(out.aim_lead_cap)) return false;
    if (out.aim_lead_cap < 0) return false;
    if (!input.read_f64(out.approach_distance)) return false;
    if (out.approach_distance < 0) return false;
    if (!input.read_f64(out.threshold_1)) return false;
    if (out.threshold_1 < 0) return false;
    if (!input.read_f64(out.threshold_2)) return false;
    if (out.threshold_2 < 0) return false;
    if (!input.read_u32(out.body_segments)) return false;
    if (out.body_segments < 1) return false;
    if (out.body_segments > 2048) return false;
    if (!input.read_f64(out.head_radius)) return false;
    if (out.head_radius < 0) return false;
    if (!input.read_f64(out.part_hp)) return false;
    if (out.part_hp < 0) return false;
    if (!input.read_f64(out.part_armor)) return false;
    if (out.part_armor < 0) return false;
    if (!input.read_f64(out.entrance_quiet)) return false;
    if (out.entrance_quiet < 0) return false;
    return true;
}
struct DracoCycleDefinition {
    uint32_t id{};
    uint32_t boss{};
    double collect_time{};
    uint32_t count{};
};
inline bool read(BinaryReader &input, DracoCycleDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.boss)) return false;
    if (!input.read_f64(out.collect_time)) return false;
    if (out.collect_time < 0) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count > 2048) return false;
    return true;
}
struct DracoCycleCandidate {
    uint32_t id{};
    uint32_t cycle{};
    uint32_t enemy{};
    bool excluded{};
};
inline bool read(BinaryReader &input, DracoCycleCandidate &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.cycle)) return false;
    if (!input.read_u32(out.enemy)) return false;
    if (!input.read_bool(out.excluded)) return false;
    return true;
}
struct DracoBiteDefinition {
    uint32_t id{};
    uint32_t technique{};
    double lead_cap{};
    double retract{};
};
inline bool read(BinaryReader &input, DracoBiteDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.lead_cap)) return false;
    if (out.lead_cap < 0) return false;
    if (!input.read_f64(out.retract)) return false;
    if (out.retract < 0) return false;
    return true;
}
struct DracoBreathDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t rock_enemy{};
    uint32_t rocks{};
    double rock_distance{};
    double rock_spacing{};
    double half_angle{};
    double sweep{};
};
inline bool read(BinaryReader &input, DracoBreathDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.rock_enemy)) return false;
    if (!input.read_u32(out.rocks)) return false;
    if (out.rocks > 2048) return false;
    if (!input.read_f64(out.rock_distance)) return false;
    if (out.rock_distance < 0) return false;
    if (!input.read_f64(out.rock_spacing)) return false;
    if (out.rock_spacing < 0) return false;
    if (!input.read_f64(out.half_angle)) return false;
    if (out.half_angle < 0) return false;
    if (!input.read_f64(out.sweep)) return false;
    if (out.sweep < 0) return false;
    return true;
}
struct DracoChargeDefinition {
    uint32_t id{};
    uint32_t technique{};
    double lead_cap{};
    double overshoot{};
};
inline bool read(BinaryReader &input, DracoChargeDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.lead_cap)) return false;
    if (out.lead_cap < 0) return false;
    if (!input.read_f64(out.overshoot)) return false;
    if (out.overshoot < 0) return false;
    return true;
}
struct DracoLeapDefinition {
    uint32_t id{};
    uint32_t technique{};
    double lead_cap{};
};
inline bool read(BinaryReader &input, DracoLeapDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.lead_cap)) return false;
    if (out.lead_cap < 0) return false;
    return true;
}
struct DracoTailSlamDefinition {
    uint32_t id{};
    uint32_t technique{};
    double lead_cap{};
    double radius{};
};
inline bool read(BinaryReader &input, DracoTailSlamDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.lead_cap)) return false;
    if (out.lead_cap < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    return true;
}
struct DracoTailSweepDefinition {
    uint32_t id{};
    uint32_t technique{};
    double half_angle{};
};
inline bool read(BinaryReader &input, DracoTailSweepDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.half_angle)) return false;
    if (out.half_angle < 0) return false;
    if (out.half_angle > 3.141592653589793) return false;
    return true;
}
struct DracoStarFanDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t projectile{};
    double lead_cap{};
    uint32_t count{};
    double arc{};
    double radius{};
    double speed{};
};
inline bool read(BinaryReader &input, DracoStarFanDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.projectile)) return false;
    if (!input.read_f64(out.lead_cap)) return false;
    if (out.lead_cap < 0) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count > 2048) return false;
    if (!input.read_f64(out.arc)) return false;
    if (out.arc < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    if (!input.read_f64(out.speed)) return false;
    if (out.speed < 0) return false;
    return true;
}
struct DracoMeteorDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t rock_enemy{};
    uint32_t rocks{};
    double rock_distance{};
    double rock_spacing{};
};
inline bool read(BinaryReader &input, DracoMeteorDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.rock_enemy)) return false;
    if (!input.read_u32(out.rocks)) return false;
    if (out.rocks > 2048) return false;
    if (!input.read_f64(out.rock_distance)) return false;
    if (out.rock_distance < 0) return false;
    if (!input.read_f64(out.rock_spacing)) return false;
    if (out.rock_spacing < 0) return false;
    return true;
}
struct DracoRiftsDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t claw_count{};
    double claw_angle{};
    double claw_gap{};
    double claw_offset{};
    double claw_overshoot{};
    double interval{};
    double scratch_time{};
    double scratch_width{};
};
inline bool read(BinaryReader &input, DracoRiftsDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.claw_count)) return false;
    if (out.claw_count > 2048) return false;
    if (!input.read_f64(out.claw_angle)) return false;
    if (out.claw_angle < 0) return false;
    if (!input.read_f64(out.claw_gap)) return false;
    if (out.claw_gap < 0) return false;
    if (!input.read_f64(out.claw_offset)) return false;
    if (out.claw_offset < 0) return false;
    if (!input.read_f64(out.claw_overshoot)) return false;
    if (out.claw_overshoot < 0) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.scratch_time)) return false;
    if (out.scratch_time < 0) return false;
    if (!input.read_f64(out.scratch_width)) return false;
    if (out.scratch_width < 0) return false;
    return true;
}
struct DracoPicaroWallDefinition {
    uint32_t id{};
    uint32_t technique{};
    uint32_t count{};
    uint32_t arrows{};
    double interval{};
    double flight{};
    double impact_warn{};
    double radius{};
};
inline bool read(BinaryReader &input, DracoPicaroWallDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.count)) return false;
    if (out.count > 2048) return false;
    if (!input.read_u32(out.arrows)) return false;
    if (out.arrows > 2048) return false;
    if (!input.read_f64(out.interval)) return false;
    if (out.interval < 0) return false;
    if (!input.read_f64(out.flight)) return false;
    if (out.flight < 0) return false;
    if (!input.read_f64(out.impact_warn)) return false;
    if (out.impact_warn < 0) return false;
    if (!input.read_f64(out.radius)) return false;
    if (out.radius < 0) return false;
    return true;
}
struct DracoPicaroWallCandidate {
    uint32_t id{};
    uint32_t technique{};
    uint32_t enemy{};
};
inline bool read(BinaryReader &input, DracoPicaroWallCandidate &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_u32(out.enemy)) return false;
    return true;
}
struct DracoSpiralDefinition {
    uint32_t id{};
    uint32_t technique{};
    double radius_factor{};
    double aspect_ratio{};
    double inner_radius_factor{};
    double coil_time{};
    double pause{};
    double head_offset{};
    double exit_duration{};
    double spiral_length{};
    double shrink_time{};
    double touch_invuln{};
};
inline bool read(BinaryReader &input, DracoSpiralDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
    if (!input.read_u32(out.technique)) return false;
    if (!input.read_f64(out.radius_factor)) return false;
    if (out.radius_factor < 0) return false;
    if (!input.read_f64(out.aspect_ratio)) return false;
    if (out.aspect_ratio < 0) return false;
    if (!input.read_f64(out.inner_radius_factor)) return false;
    if (out.inner_radius_factor < 0) return false;
    if (!input.read_f64(out.coil_time)) return false;
    if (out.coil_time < 0) return false;
    if (!input.read_f64(out.pause)) return false;
    if (out.pause < 0) return false;
    if (!input.read_f64(out.head_offset)) return false;
    if (out.head_offset < 0) return false;
    if (!input.read_f64(out.exit_duration)) return false;
    if (out.exit_duration < 0) return false;
    if (!input.read_f64(out.spiral_length)) return false;
    if (out.spiral_length < 0) return false;
    if (!input.read_f64(out.shrink_time)) return false;
    if (out.shrink_time < 0) return false;
    if (!input.read_f64(out.touch_invuln)) return false;
    if (out.touch_invuln < 0) return false;
    return true;
}
struct ContentRecords {
    std::vector<RunConfig> RunConfig_rows;
    std::vector<StringEntry> StringEntry_rows;
    std::vector<DefinitionIndex> DefinitionIndex_rows;
    std::vector<EnemyRecord> EnemyRecord_rows;
    std::vector<LoadoutDefinition> LoadoutDefinition_rows;
    std::vector<HeroDefinition> HeroDefinition_rows;
    std::vector<FieldDefinition> FieldDefinition_rows;
    std::vector<PopulationDefinition> PopulationDefinition_rows;
    std::vector<FormationDefinition> FormationDefinition_rows;
    std::vector<BossFlowDefinition> BossFlowDefinition_rows;
    std::vector<TechniqueDefinition> TechniqueDefinition_rows;
    std::vector<ResourceKey> ResourceKey_rows;
    std::vector<ForwardDefinition> ForwardDefinition_rows;
    std::vector<BiteDefinition> BiteDefinition_rows;
    std::vector<LifecycleDefinition> LifecycleDefinition_rows;
    std::vector<EnemyTuningValue> EnemyTuningValue_rows;
    std::vector<ContactDefinition> ContactDefinition_rows;
    std::vector<HostileDefinition> HostileDefinition_rows;
    std::vector<BeamDefinition> BeamDefinition_rows;
    std::vector<FriendShotDefinition> FriendShotDefinition_rows;
    std::vector<WaveDefinition> WaveDefinition_rows;
    std::vector<WallDefinition> WallDefinition_rows;
    std::vector<SlashDefinition> SlashDefinition_rows;
    std::vector<BoltDefinition> BoltDefinition_rows;
    std::vector<LightArrowDefinition> LightArrowDefinition_rows;
    std::vector<StarBoltDefinition> StarBoltDefinition_rows;
    std::vector<RingHoldDefinition> RingHoldDefinition_rows;
    std::vector<LumpDefinition> LumpDefinition_rows;
    std::vector<FriendDebrisDefinition> FriendDebrisDefinition_rows;
    std::vector<FriendHullDefinition> FriendHullDefinition_rows;
    std::vector<FriendHullLook> FriendHullLook_rows;
    std::vector<FriendSawPoint> FriendSawPoint_rows;
    std::vector<ZoneDefinition> ZoneDefinition_rows;
    std::vector<FloodDefinition> FloodDefinition_rows;
    std::vector<LightLanceDefinition> LightLanceDefinition_rows;
    std::vector<ShellDefinition> ShellDefinition_rows;
    std::vector<ShellSource> ShellSource_rows;
    std::vector<BudgetPhase> BudgetPhase_rows;
    std::vector<PopulationPhase> PopulationPhase_rows;
    std::vector<PopulationMix> PopulationMix_rows;
    std::vector<PopulationCurve> PopulationCurve_rows;
    std::vector<PopulationPoint> PopulationPoint_rows;
    std::vector<PopulationWindow> PopulationWindow_rows;
    std::vector<PopulationType> PopulationType_rows;
    std::vector<FormationEntry> FormationEntry_rows;
    std::vector<FormationLayout> FormationLayout_rows;
    std::vector<FormationType> FormationType_rows;
    std::vector<FormationMarker> FormationMarker_rows;
    std::vector<PopulationClip> PopulationClip_rows;
    std::vector<PopulationClipType> PopulationClipType_rows;
    std::vector<PopulationClipFormation> PopulationClipFormation_rows;
    std::vector<DeathChainDefinition> DeathChainDefinition_rows;
    std::vector<EncounterDefinition> EncounterDefinition_rows;
    std::vector<EncounterPattern> EncounterPattern_rows;
    std::vector<EncounterPoint> EncounterPoint_rows;
    std::vector<EncounterRegion> EncounterRegion_rows;
    std::vector<EncounterPhase> EncounterPhase_rows;
    std::vector<ProgressionDefinition> ProgressionDefinition_rows;
    std::vector<LoadoutAsset> LoadoutAsset_rows;
    std::vector<PostMaxDefinition> PostMaxDefinition_rows;
    std::vector<PostMaxTarget> PostMaxTarget_rows;
    std::vector<PostMaxInterval> PostMaxInterval_rows;
    std::vector<HoundDefinition> HoundDefinition_rows;
    std::vector<ShieldDefinition> ShieldDefinition_rows;
    std::vector<GunnerDefinition> GunnerDefinition_rows;
    std::vector<BeamerDefinition> BeamerDefinition_rows;
    std::vector<MissileEnemyDefinition> MissileEnemyDefinition_rows;
    std::vector<RocketDefinition> RocketDefinition_rows;
    std::vector<DriftDefinition> DriftDefinition_rows;
    std::vector<PartDefinition> PartDefinition_rows;
    std::vector<DashDefinition> DashDefinition_rows;
    std::vector<BattleshipDefinition> BattleshipDefinition_rows;
    std::vector<SniperDefinition> SniperDefinition_rows;
    std::vector<MarlinDefinition> MarlinDefinition_rows;
    std::vector<PulserDefinition> PulserDefinition_rows;
    std::vector<DolphinDefinition> DolphinDefinition_rows;
    std::vector<LynxDefinition> LynxDefinition_rows;
    std::vector<SoldierDefinition> SoldierDefinition_rows;
    std::vector<AurigaDefinition> AurigaDefinition_rows;
    std::vector<ClockDefinition> ClockDefinition_rows;
    std::vector<ReticleDefinition> ReticleDefinition_rows;
    std::vector<AquariusDefinition> AquariusDefinition_rows;
    std::vector<CrossEnemyDefinition> CrossEnemyDefinition_rows;
    std::vector<BomberDefinition> BomberDefinition_rows;
    std::vector<PhoenixDefinition> PhoenixDefinition_rows;
    std::vector<AquilaDefinition> AquilaDefinition_rows;
    std::vector<SplitDefinition> SplitDefinition_rows;
    std::vector<DefenderDefinition> DefenderDefinition_rows;
    std::vector<CrabDefinition> CrabDefinition_rows;
    std::vector<CrowDefinition> CrowDefinition_rows;
    std::vector<CepheusDefinition> CepheusDefinition_rows;
    std::vector<PumpDefinition> PumpDefinition_rows;
    std::vector<TriangleStarDefinition> TriangleStarDefinition_rows;
    std::vector<CoronaDefinition> CoronaDefinition_rows;
    std::vector<CoronaType> CoronaType_rows;
    std::vector<RulerDefinition> RulerDefinition_rows;
    std::vector<TriangleDefinition> TriangleDefinition_rows;
    std::vector<FieldBodyDefinition> FieldBodyDefinition_rows;
    std::vector<MoonDefinition> MoonDefinition_rows;
    std::vector<RockFieldDefinition> RockFieldDefinition_rows;
    std::vector<GravityDefinition> GravityDefinition_rows;
    std::vector<WarpDefinition> WarpDefinition_rows;
    std::vector<CometDefinition> CometDefinition_rows;
    std::vector<NumericTraitLevel> NumericTraitLevel_rows;
    std::vector<PostMaxChargeDefinition> PostMaxChargeDefinition_rows;
    std::vector<PostMaxCritDefinition> PostMaxCritDefinition_rows;
    std::vector<PostMaxMotionDefinition> PostMaxMotionDefinition_rows;
    std::vector<PostMaxWeaponPowerDefinition> PostMaxWeaponPowerDefinition_rows;
    std::vector<PostMaxPickupDefinition> PostMaxPickupDefinition_rows;
    std::vector<PostMaxDrawDefinition> PostMaxDrawDefinition_rows;
    std::vector<ScatterDefinition> ScatterDefinition_rows;
    std::vector<ScatterPostDefinition> ScatterPostDefinition_rows;
    std::vector<RearDefinition> RearDefinition_rows;
    std::vector<RearPostDefinition> RearPostDefinition_rows;
    std::vector<BarrierDefinition> BarrierDefinition_rows;
    std::vector<BarrierPostDefinition> BarrierPostDefinition_rows;
    std::vector<FullChargeDefinition> FullChargeDefinition_rows;
    std::vector<RampageDefinition> RampageDefinition_rows;
    std::vector<DuplicatorDefinition> DuplicatorDefinition_rows;
    std::vector<EndBlastDefinition> EndBlastDefinition_rows;
    std::vector<RunUpDefinition> RunUpDefinition_rows;
    std::vector<MinesDefinition> MinesDefinition_rows;
    std::vector<VortexDefinition> VortexDefinition_rows;
    std::vector<CritBeamDefinition> CritBeamDefinition_rows;
    std::vector<KnockbackDefinition> KnockbackDefinition_rows;
    std::vector<ContactWaveDefinition> ContactWaveDefinition_rows;
    std::vector<SonicDefinition> SonicDefinition_rows;
    std::vector<ContactArcDefinition> ContactArcDefinition_rows;
    std::vector<KillSonicDefinition> KillSonicDefinition_rows;
    std::vector<MassTowDefinition> MassTowDefinition_rows;
    std::vector<BipolarDefinition> BipolarDefinition_rows;
    std::vector<InterceptorDefinition> InterceptorDefinition_rows;
    std::vector<DashRangeDroneDefinition> DashRangeDroneDefinition_rows;
    std::vector<AfterimageDefinition> AfterimageDefinition_rows;
    std::vector<FlashSlashDefinition> FlashSlashDefinition_rows;
    std::vector<BossDefinition> BossDefinition_rows;
    std::vector<BossTechniqueDefinition> BossTechniqueDefinition_rows;
    std::vector<BossTechniqueStage> BossTechniqueStage_rows;
    std::vector<BossBodyDefinition> BossBodyDefinition_rows;
    std::vector<BossFinishDefinition> BossFinishDefinition_rows;
    std::vector<BossFlowProgram> BossFlowProgram_rows;
    std::vector<BossFlowSection> BossFlowSection_rows;
    std::vector<BossFlowCondition> BossFlowCondition_rows;
    std::vector<BossFlowNode> BossFlowNode_rows;
    std::vector<BossFlowChild> BossFlowChild_rows;
    std::vector<BossFlowAction> BossFlowAction_rows;
    std::vector<BossFlowFilter> BossFlowFilter_rows;
    std::vector<BossFlowWeight> BossFlowWeight_rows;
    std::vector<BossFlowForbidden> BossFlowForbidden_rows;
    std::vector<HeroStar> HeroStar_rows;
    std::vector<HeroLink> HeroLink_rows;
    std::vector<HeroConfig> HeroConfig_rows;
    std::vector<PerseusDefinition> PerseusDefinition_rows;
    std::vector<LeoDefinition> LeoDefinition_rows;
    std::vector<GeminiDefinition> GeminiDefinition_rows;
    std::vector<HerculesDefinition> HerculesDefinition_rows;
    std::vector<CentaurusBodyDefinition> CentaurusBodyDefinition_rows;
    std::vector<CentaurusVolleyDefinition> CentaurusVolleyDefinition_rows;
    std::vector<CentaurusRearDefinition> CentaurusRearDefinition_rows;
    std::vector<CentaurusRainDefinition> CentaurusRainDefinition_rows;
    std::vector<CentaurusPowerDefinition> CentaurusPowerDefinition_rows;
    std::vector<CentaurusStompDefinition> CentaurusStompDefinition_rows;
    std::vector<CentaurusStompFoot> CentaurusStompFoot_rows;
    std::vector<CentaurusFanDefinition> CentaurusFanDefinition_rows;
    std::vector<CentaurusShowerDefinition> CentaurusShowerDefinition_rows;
    std::vector<CentaurusSailDefinition> CentaurusSailDefinition_rows;
    std::vector<CentaurusComboDefinition> CentaurusComboDefinition_rows;
    std::vector<CanisBodyDefinition> CanisBodyDefinition_rows;
    std::vector<CanisFlameDefinition> CanisFlameDefinition_rows;
    std::vector<CanisCommandDefinition> CanisCommandDefinition_rows;
    std::vector<CanisHowlDefinition> CanisHowlDefinition_rows;
    std::vector<CanisPounceDefinition> CanisPounceDefinition_rows;
    std::vector<CanisSiriusDefinition> CanisSiriusDefinition_rows;
    std::vector<CanisBayDefinition> CanisBayDefinition_rows;
    std::vector<CanisBlazeDefinition> CanisBlazeDefinition_rows;
    std::vector<CanisStreamDefinition> CanisStreamDefinition_rows;
    std::vector<CanisHuntDefinition> CanisHuntDefinition_rows;
    std::vector<CanisHuntPounceDefinition> CanisHuntPounceDefinition_rows;
    std::vector<CanisNovaDefinition> CanisNovaDefinition_rows;
    std::vector<CanisRelayDefinition> CanisRelayDefinition_rows;
    std::vector<CanisSiriusFlameDefinition> CanisSiriusFlameDefinition_rows;
    std::vector<HydraBodyDefinition> HydraBodyDefinition_rows;
    std::vector<HydraRegrowDefinition> HydraRegrowDefinition_rows;
    std::vector<HydraNormalDefinition> HydraNormalDefinition_rows;
    std::vector<HydraSwimDefinition> HydraSwimDefinition_rows;
    std::vector<HydraNormalGate> HydraNormalGate_rows;
    std::vector<HydraSquadDefinition> HydraSquadDefinition_rows;
    std::vector<HydraSweepDefinition> HydraSweepDefinition_rows;
    std::vector<HydraBoltDefinition> HydraBoltDefinition_rows;
    std::vector<HydraFixedBeamDefinition> HydraFixedBeamDefinition_rows;
    std::vector<HydraWindBladesDefinition> HydraWindBladesDefinition_rows;
    std::vector<HydraCurveDefinition> HydraCurveDefinition_rows;
    std::vector<HydraMajorDefinition> HydraMajorDefinition_rows;
    std::vector<HydraGridDefinition> HydraGridDefinition_rows;
    std::vector<HydraGridLayout> HydraGridLayout_rows;
    std::vector<HydraGridSlot> HydraGridSlot_rows;
    std::vector<HydraGridPath> HydraGridPath_rows;
    std::vector<HydraRubbleDefinition> HydraRubbleDefinition_rows;
    std::vector<HydraPincerDefinition> HydraPincerDefinition_rows;
    std::vector<HydraTornadoDefinition> HydraTornadoDefinition_rows;
    std::vector<HydraShatterDefinition> HydraShatterDefinition_rows;
    std::vector<HydraThunderDefinition> HydraThunderDefinition_rows;
    std::vector<HydraWindBandDefinition> HydraWindBandDefinition_rows;
    std::vector<HydraNorthDefinition> HydraNorthDefinition_rows;
    std::vector<HydraSequenceDefinition> HydraSequenceDefinition_rows;
    std::vector<HydraSwarmDefinition> HydraSwarmDefinition_rows;
    std::vector<DracoBodyDefinition> DracoBodyDefinition_rows;
    std::vector<DracoCycleDefinition> DracoCycleDefinition_rows;
    std::vector<DracoCycleCandidate> DracoCycleCandidate_rows;
    std::vector<DracoBiteDefinition> DracoBiteDefinition_rows;
    std::vector<DracoBreathDefinition> DracoBreathDefinition_rows;
    std::vector<DracoChargeDefinition> DracoChargeDefinition_rows;
    std::vector<DracoLeapDefinition> DracoLeapDefinition_rows;
    std::vector<DracoTailSlamDefinition> DracoTailSlamDefinition_rows;
    std::vector<DracoTailSweepDefinition> DracoTailSweepDefinition_rows;
    std::vector<DracoStarFanDefinition> DracoStarFanDefinition_rows;
    std::vector<DracoMeteorDefinition> DracoMeteorDefinition_rows;
    std::vector<DracoRiftsDefinition> DracoRiftsDefinition_rows;
    std::vector<DracoPicaroWallDefinition> DracoPicaroWallDefinition_rows;
    std::vector<DracoPicaroWallCandidate> DracoPicaroWallCandidate_rows;
    std::vector<DracoSpiralDefinition> DracoSpiralDefinition_rows;
};
inline bool read_section(uint32_t kind, uint32_t version, uint32_t count, BinaryReader &input, ContentRecords &out) {
    switch(kind) {
    case 1: {
        if (version != 9) return false;
        if (count > input.remaining()/672) return false;
        for (uint32_t i=0; i<count; ++i) { RunConfig row; if (!read(input,row)) return false; out.RunConfig_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 2: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { StringEntry row; if (!read(input,row)) return false; out.StringEntry_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 3: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { DefinitionIndex row; if (!read(input,row)) return false; out.DefinitionIndex_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 4: {
        if (version != 9) return false;
        if (count > input.remaining()/250) return false;
        for (uint32_t i=0; i<count; ++i) { EnemyRecord row; if (!read(input,row)) return false; out.EnemyRecord_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 5: {
        if (version != 4) return false;
        if (count > input.remaining()/17) return false;
        for (uint32_t i=0; i<count; ++i) { LoadoutDefinition row; if (!read(input,row)) return false; out.LoadoutDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 6: {
        if (version != 2) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { HeroDefinition row; if (!read(input,row)) return false; out.HeroDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 7: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { FieldDefinition row; if (!read(input,row)) return false; out.FieldDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 8: {
        if (version != 2) return false;
        if (count > input.remaining()/85) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationDefinition row; if (!read(input,row)) return false; out.PopulationDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 9: {
        if (version != 2) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { FormationDefinition row; if (!read(input,row)) return false; out.FormationDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 10: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowDefinition row; if (!read(input,row)) return false; out.BossFlowDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 11: {
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { TechniqueDefinition row; if (!read(input,row)) return false; out.TechniqueDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 12: {
        if (version != 12) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { ResourceKey row; if (!read(input,row)) return false; out.ResourceKey_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 13: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { ForwardDefinition row; if (!read(input,row)) return false; out.ForwardDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 14: {
        if (version != 2) return false;
        if (count > input.remaining()/58) return false;
        for (uint32_t i=0; i<count; ++i) { BiteDefinition row; if (!read(input,row)) return false; out.BiteDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 20: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { LifecycleDefinition row; if (!read(input,row)) return false; out.LifecycleDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 250: {
        if (version != 1) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { EnemyTuningValue row; if (!read(input,row)) return false; out.EnemyTuningValue_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 15: {
        if (version != 1) return false;
        if (count > input.remaining()/26) return false;
        for (uint32_t i=0; i<count; ++i) { ContactDefinition row; if (!read(input,row)) return false; out.ContactDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 24: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { HostileDefinition row; if (!read(input,row)) return false; out.HostileDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 26: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { BeamDefinition row; if (!read(input,row)) return false; out.BeamDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 27: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { FriendShotDefinition row; if (!read(input,row)) return false; out.FriendShotDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 37: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { WaveDefinition row; if (!read(input,row)) return false; out.WaveDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 38: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { WallDefinition row; if (!read(input,row)) return false; out.WallDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 42: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { SlashDefinition row; if (!read(input,row)) return false; out.SlashDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 43: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { BoltDefinition row; if (!read(input,row)) return false; out.BoltDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 48: {
        if (version != 1) return false;
        if (count > input.remaining()/117) return false;
        for (uint32_t i=0; i<count; ++i) { LightArrowDefinition row; if (!read(input,row)) return false; out.LightArrowDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 51: {
        if (version != 1) return false;
        if (count > input.remaining()/57) return false;
        for (uint32_t i=0; i<count; ++i) { StarBoltDefinition row; if (!read(input,row)) return false; out.StarBoltDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 54: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { RingHoldDefinition row; if (!read(input,row)) return false; out.RingHoldDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 55: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { LumpDefinition row; if (!read(input,row)) return false; out.LumpDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 60: {
        if (version != 1) return false;
        if (count > input.remaining()/80) return false;
        for (uint32_t i=0; i<count; ++i) { FriendDebrisDefinition row; if (!read(input,row)) return false; out.FriendDebrisDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 61: {
        if (version != 1) return false;
        if (count > input.remaining()/40) return false;
        for (uint32_t i=0; i<count; ++i) { FriendHullDefinition row; if (!read(input,row)) return false; out.FriendHullDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 62: {
        if (version != 1) return false;
        if (count > input.remaining()/25) return false;
        for (uint32_t i=0; i<count; ++i) { FriendHullLook row; if (!read(input,row)) return false; out.FriendHullLook_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 63: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { FriendSawPoint row; if (!read(input,row)) return false; out.FriendSawPoint_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 68: {
        if (version != 1) return false;
        if (count > input.remaining()/102) return false;
        for (uint32_t i=0; i<count; ++i) { ZoneDefinition row; if (!read(input,row)) return false; out.ZoneDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 70: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { FloodDefinition row; if (!read(input,row)) return false; out.FloodDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 72: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { LightLanceDefinition row; if (!read(input,row)) return false; out.LightLanceDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 80: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { ShellDefinition row; if (!read(input,row)) return false; out.ShellDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 81: {
        if (version != 1) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { ShellSource row; if (!read(input,row)) return false; out.ShellSource_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 16: {
        if (version != 1) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { BudgetPhase row; if (!read(input,row)) return false; out.BudgetPhase_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 84: {
        if (version != 1) return false;
        if (count > input.remaining()/96) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationPhase row; if (!read(input,row)) return false; out.PopulationPhase_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 85: {
        if (version != 1) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationMix row; if (!read(input,row)) return false; out.PopulationMix_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 86: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationCurve row; if (!read(input,row)) return false; out.PopulationCurve_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 87: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationPoint row; if (!read(input,row)) return false; out.PopulationPoint_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 88: {
        if (version != 1) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationWindow row; if (!read(input,row)) return false; out.PopulationWindow_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 89: {
        if (version != 1) return false;
        if (count > input.remaining()/25) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationType row; if (!read(input,row)) return false; out.PopulationType_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 180: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { FormationEntry row; if (!read(input,row)) return false; out.FormationEntry_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 181: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { FormationLayout row; if (!read(input,row)) return false; out.FormationLayout_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 182: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { FormationType row; if (!read(input,row)) return false; out.FormationType_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 183: {
        if (version != 1) return false;
        if (count > input.remaining()/40) return false;
        for (uint32_t i=0; i<count; ++i) { FormationMarker row; if (!read(input,row)) return false; out.FormationMarker_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 184: {
        if (version != 1) return false;
        if (count > input.remaining()/40) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationClip row; if (!read(input,row)) return false; out.PopulationClip_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 185: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationClipType row; if (!read(input,row)) return false; out.PopulationClipType_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 186: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { PopulationClipFormation row; if (!read(input,row)) return false; out.PopulationClipFormation_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 187: {
        if (version != 1) return false;
        if (count > input.remaining()/36) return false;
        for (uint32_t i=0; i<count; ++i) { DeathChainDefinition row; if (!read(input,row)) return false; out.DeathChainDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 188: {
        if (version != 1) return false;
        if (count > input.remaining()/13) return false;
        for (uint32_t i=0; i<count; ++i) { EncounterDefinition row; if (!read(input,row)) return false; out.EncounterDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 189: {
        if (version != 1) return false;
        if (count > input.remaining()/76) return false;
        for (uint32_t i=0; i<count; ++i) { EncounterPattern row; if (!read(input,row)) return false; out.EncounterPattern_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 190: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { EncounterPoint row; if (!read(input,row)) return false; out.EncounterPoint_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 191: {
        if (version != 1) return false;
        if (count > input.remaining()/54) return false;
        for (uint32_t i=0; i<count; ++i) { EncounterRegion row; if (!read(input,row)) return false; out.EncounterRegion_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 192: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { EncounterPhase row; if (!read(input,row)) return false; out.EncounterPhase_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 17: {
        if (version != 1) return false;
        if (count > input.remaining()/84) return false;
        for (uint32_t i=0; i<count; ++i) { ProgressionDefinition row; if (!read(input,row)) return false; out.ProgressionDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 18: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { LoadoutAsset row; if (!read(input,row)) return false; out.LoadoutAsset_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 400: {
        if (version != 1) return false;
        if (count > input.remaining()/40) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxDefinition row; if (!read(input,row)) return false; out.PostMaxDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 401: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxTarget row; if (!read(input,row)) return false; out.PostMaxTarget_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 402: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxInterval row; if (!read(input,row)) return false; out.PostMaxInterval_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 19: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { HoundDefinition row; if (!read(input,row)) return false; out.HoundDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 25: {
        if (version != 1) return false;
        if (count > input.remaining()/64) return false;
        for (uint32_t i=0; i<count; ++i) { ShieldDefinition row; if (!read(input,row)) return false; out.ShieldDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 28: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { GunnerDefinition row; if (!read(input,row)) return false; out.GunnerDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 29: {
        if (version != 1) return false;
        if (count > input.remaining()/69) return false;
        for (uint32_t i=0; i<count; ++i) { BeamerDefinition row; if (!read(input,row)) return false; out.BeamerDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 39: {
        if (version != 1) return false;
        if (count > input.remaining()/68) return false;
        for (uint32_t i=0; i<count; ++i) { MissileEnemyDefinition row; if (!read(input,row)) return false; out.MissileEnemyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 44: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { RocketDefinition row; if (!read(input,row)) return false; out.RocketDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 47: {
        if (version != 1) return false;
        if (count > input.remaining()/14) return false;
        for (uint32_t i=0; i<count; ++i) { DriftDefinition row; if (!read(input,row)) return false; out.DriftDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 49: {
        if (version != 1) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { PartDefinition row; if (!read(input,row)) return false; out.PartDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 50: {
        if (version != 1) return false;
        if (count > input.remaining()/52) return false;
        for (uint32_t i=0; i<count; ++i) { DashDefinition row; if (!read(input,row)) return false; out.DashDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 57: {
        if (version != 1) return false;
        if (count > input.remaining()/64) return false;
        for (uint32_t i=0; i<count; ++i) { BattleshipDefinition row; if (!read(input,row)) return false; out.BattleshipDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 59: {
        if (version != 1) return false;
        if (count > input.remaining()/140) return false;
        for (uint32_t i=0; i<count; ++i) { SniperDefinition row; if (!read(input,row)) return false; out.SniperDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 64: {
        if (version != 1) return false;
        if (count > input.remaining()/52) return false;
        for (uint32_t i=0; i<count; ++i) { MarlinDefinition row; if (!read(input,row)) return false; out.MarlinDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 65: {
        if (version != 1) return false;
        if (count > input.remaining()/68) return false;
        for (uint32_t i=0; i<count; ++i) { PulserDefinition row; if (!read(input,row)) return false; out.PulserDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 66: {
        if (version != 1) return false;
        if (count > input.remaining()/84) return false;
        for (uint32_t i=0; i<count; ++i) { DolphinDefinition row; if (!read(input,row)) return false; out.DolphinDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 69: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { LynxDefinition row; if (!read(input,row)) return false; out.LynxDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 71: {
        if (version != 1) return false;
        if (count > input.remaining()/36) return false;
        for (uint32_t i=0; i<count; ++i) { SoldierDefinition row; if (!read(input,row)) return false; out.SoldierDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 73: {
        if (version != 1) return false;
        if (count > input.remaining()/52) return false;
        for (uint32_t i=0; i<count; ++i) { AurigaDefinition row; if (!read(input,row)) return false; out.AurigaDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 74: {
        if (version != 1) return false;
        if (count > input.remaining()/68) return false;
        for (uint32_t i=0; i<count; ++i) { ClockDefinition row; if (!read(input,row)) return false; out.ClockDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 76: {
        if (version != 1) return false;
        if (count > input.remaining()/68) return false;
        for (uint32_t i=0; i<count; ++i) { ReticleDefinition row; if (!read(input,row)) return false; out.ReticleDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 104: {
        if (version != 1) return false;
        if (count > input.remaining()/88) return false;
        for (uint32_t i=0; i<count; ++i) { AquariusDefinition row; if (!read(input,row)) return false; out.AquariusDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 100: {
        if (version != 1) return false;
        if (count > input.remaining()/84) return false;
        for (uint32_t i=0; i<count; ++i) { CrossEnemyDefinition row; if (!read(input,row)) return false; out.CrossEnemyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 101: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { BomberDefinition row; if (!read(input,row)) return false; out.BomberDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 102: {
        if (version != 1) return false;
        if (count > input.remaining()/76) return false;
        for (uint32_t i=0; i<count; ++i) { PhoenixDefinition row; if (!read(input,row)) return false; out.PhoenixDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 103: {
        if (version != 1) return false;
        if (count > input.remaining()/92) return false;
        for (uint32_t i=0; i<count; ++i) { AquilaDefinition row; if (!read(input,row)) return false; out.AquilaDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 120: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { SplitDefinition row; if (!read(input,row)) return false; out.SplitDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 121: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { DefenderDefinition row; if (!read(input,row)) return false; out.DefenderDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 130: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { CrabDefinition row; if (!read(input,row)) return false; out.CrabDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 140: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { CrowDefinition row; if (!read(input,row)) return false; out.CrowDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 110: {
        if (version != 1) return false;
        if (count > input.remaining()/96) return false;
        for (uint32_t i=0; i<count; ++i) { CepheusDefinition row; if (!read(input,row)) return false; out.CepheusDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 131: {
        if (version != 1) return false;
        if (count > input.remaining()/172) return false;
        for (uint32_t i=0; i<count; ++i) { PumpDefinition row; if (!read(input,row)) return false; out.PumpDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 112: {
        if (version != 1) return false;
        if (count > input.remaining()/4) return false;
        for (uint32_t i=0; i<count; ++i) { TriangleStarDefinition row; if (!read(input,row)) return false; out.TriangleStarDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 132: {
        if (version != 1) return false;
        if (count > input.remaining()/96) return false;
        for (uint32_t i=0; i<count; ++i) { CoronaDefinition row; if (!read(input,row)) return false; out.CoronaDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 133: {
        if (version != 1) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { CoronaType row; if (!read(input,row)) return false; out.CoronaType_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 113: {
        if (version != 1) return false;
        if (count > input.remaining()/116) return false;
        for (uint32_t i=0; i<count; ++i) { RulerDefinition row; if (!read(input,row)) return false; out.RulerDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 170: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { TriangleDefinition row; if (!read(input,row)) return false; out.TriangleDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 21: {
        if (version != 1) return false;
        if (count > input.remaining()/36) return false;
        for (uint32_t i=0; i<count; ++i) { FieldBodyDefinition row; if (!read(input,row)) return false; out.FieldBodyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 22: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { MoonDefinition row; if (!read(input,row)) return false; out.MoonDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 23: {
        if (version != 1) return false;
        if (count > input.remaining()/124) return false;
        for (uint32_t i=0; i<count; ++i) { RockFieldDefinition row; if (!read(input,row)) return false; out.RockFieldDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 77: {
        if (version != 1) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { GravityDefinition row; if (!read(input,row)) return false; out.GravityDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 83: {
        if (version != 1) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { WarpDefinition row; if (!read(input,row)) return false; out.WarpDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 90: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { CometDefinition row; if (!read(input,row)) return false; out.CometDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 30: {
        if (version != 9) return false;
        if (count > input.remaining()/100) return false;
        for (uint32_t i=0; i<count; ++i) { NumericTraitLevel row; if (!read(input,row)) return false; out.NumericTraitLevel_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 31: {
        if (version != 1) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxChargeDefinition row; if (!read(input,row)) return false; out.PostMaxChargeDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 32: {
        if (version != 1) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxCritDefinition row; if (!read(input,row)) return false; out.PostMaxCritDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 33: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxMotionDefinition row; if (!read(input,row)) return false; out.PostMaxMotionDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 34: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxWeaponPowerDefinition row; if (!read(input,row)) return false; out.PostMaxWeaponPowerDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 35: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxPickupDefinition row; if (!read(input,row)) return false; out.PostMaxPickupDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 36: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { PostMaxDrawDefinition row; if (!read(input,row)) return false; out.PostMaxDrawDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 40: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { ScatterDefinition row; if (!read(input,row)) return false; out.ScatterDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 41: {
        if (version != 1) return false;
        if (count > input.remaining()/52) return false;
        for (uint32_t i=0; i<count; ++i) { ScatterPostDefinition row; if (!read(input,row)) return false; out.ScatterPostDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 45: {
        if (version != 1) return false;
        if (count > input.remaining()/84) return false;
        for (uint32_t i=0; i<count; ++i) { RearDefinition row; if (!read(input,row)) return false; out.RearDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 46: {
        if (version != 1) return false;
        if (count > input.remaining()/52) return false;
        for (uint32_t i=0; i<count; ++i) { RearPostDefinition row; if (!read(input,row)) return false; out.RearPostDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 52: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { BarrierDefinition row; if (!read(input,row)) return false; out.BarrierDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 53: {
        if (version != 1) return false;
        if (count > input.remaining()/36) return false;
        for (uint32_t i=0; i<count; ++i) { BarrierPostDefinition row; if (!read(input,row)) return false; out.BarrierPostDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 56: {
        if (version != 1) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { FullChargeDefinition row; if (!read(input,row)) return false; out.FullChargeDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 58: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { RampageDefinition row; if (!read(input,row)) return false; out.RampageDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 67: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { DuplicatorDefinition row; if (!read(input,row)) return false; out.DuplicatorDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 75: {
        if (version != 1) return false;
        if (count > input.remaining()/72) return false;
        for (uint32_t i=0; i<count; ++i) { EndBlastDefinition row; if (!read(input,row)) return false; out.EndBlastDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 78: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { RunUpDefinition row; if (!read(input,row)) return false; out.RunUpDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 79: {
        if (version != 1) return false;
        if (count > input.remaining()/100) return false;
        for (uint32_t i=0; i<count; ++i) { MinesDefinition row; if (!read(input,row)) return false; out.MinesDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 82: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { VortexDefinition row; if (!read(input,row)) return false; out.VortexDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 95: {
        if (version != 1) return false;
        if (count > input.remaining()/52) return false;
        for (uint32_t i=0; i<count; ++i) { CritBeamDefinition row; if (!read(input,row)) return false; out.CritBeamDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 96: {
        if (version != 1) return false;
        if (count > input.remaining()/104) return false;
        for (uint32_t i=0; i<count; ++i) { KnockbackDefinition row; if (!read(input,row)) return false; out.KnockbackDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 200: {
        if (version != 1) return false;
        if (count > input.remaining()/52) return false;
        for (uint32_t i=0; i<count; ++i) { ContactWaveDefinition row; if (!read(input,row)) return false; out.ContactWaveDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 201: {
        if (version != 1) return false;
        if (count > input.remaining()/124) return false;
        for (uint32_t i=0; i<count; ++i) { SonicDefinition row; if (!read(input,row)) return false; out.SonicDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 202: {
        if (version != 1) return false;
        if (count > input.remaining()/76) return false;
        for (uint32_t i=0; i<count; ++i) { ContactArcDefinition row; if (!read(input,row)) return false; out.ContactArcDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 240: {
        if (version != 1) return false;
        if (count > input.remaining()/76) return false;
        for (uint32_t i=0; i<count; ++i) { KillSonicDefinition row; if (!read(input,row)) return false; out.KillSonicDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 203: {
        if (version != 1) return false;
        if (count > input.remaining()/152) return false;
        for (uint32_t i=0; i<count; ++i) { MassTowDefinition row; if (!read(input,row)) return false; out.MassTowDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 204: {
        if (version != 1) return false;
        if (count > input.remaining()/96) return false;
        for (uint32_t i=0; i<count; ++i) { BipolarDefinition row; if (!read(input,row)) return false; out.BipolarDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 205: {
        if (version != 1) return false;
        if (count > input.remaining()/144) return false;
        for (uint32_t i=0; i<count; ++i) { InterceptorDefinition row; if (!read(input,row)) return false; out.InterceptorDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 206: {
        if (version != 2) return false;
        if (count > input.remaining()/80) return false;
        for (uint32_t i=0; i<count; ++i) { DashRangeDroneDefinition row; if (!read(input,row)) return false; out.DashRangeDroneDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 207: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { AfterimageDefinition row; if (!read(input,row)) return false; out.AfterimageDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 208: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { FlashSlashDefinition row; if (!read(input,row)) return false; out.FlashSlashDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 150: {
        if (version != 2) return false;
        if (count > input.remaining()/124) return false;
        for (uint32_t i=0; i<count; ++i) { BossDefinition row; if (!read(input,row)) return false; out.BossDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 151: {
        if (version != 24) return false;
        if (count > input.remaining()/637) return false;
        for (uint32_t i=0; i<count; ++i) { BossTechniqueDefinition row; if (!read(input,row)) return false; out.BossTechniqueDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 152: {
        if (version != 5) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { BossTechniqueStage row; if (!read(input,row)) return false; out.BossTechniqueStage_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 162: {
        if (version != 1) return false;
        if (count > input.remaining()/77) return false;
        for (uint32_t i=0; i<count; ++i) { BossBodyDefinition row; if (!read(input,row)) return false; out.BossBodyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 163: {
        if (version != 1) return false;
        if (count > input.remaining()/76) return false;
        for (uint32_t i=0; i<count; ++i) { BossFinishDefinition row; if (!read(input,row)) return false; out.BossFinishDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 153: {
        if (version != 1) return false;
        if (count > input.remaining()/35) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowProgram row; if (!read(input,row)) return false; out.BossFlowProgram_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 154: {
        if (version != 1) return false;
        if (count > input.remaining()/66) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowSection row; if (!read(input,row)) return false; out.BossFlowSection_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 155: {
        if (version != 1) return false;
        if (count > input.remaining()/40) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowCondition row; if (!read(input,row)) return false; out.BossFlowCondition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 156: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowNode row; if (!read(input,row)) return false; out.BossFlowNode_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 157: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowChild row; if (!read(input,row)) return false; out.BossFlowChild_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 158: {
        if (version != 1) return false;
        if (count > input.remaining()/57) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowAction row; if (!read(input,row)) return false; out.BossFlowAction_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 159: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowFilter row; if (!read(input,row)) return false; out.BossFlowFilter_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 160: {
        if (version != 1) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowWeight row; if (!read(input,row)) return false; out.BossFlowWeight_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 161: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { BossFlowForbidden row; if (!read(input,row)) return false; out.BossFlowForbidden_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 280: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { HeroStar row; if (!read(input,row)) return false; out.HeroStar_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 281: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { HeroLink row; if (!read(input,row)) return false; out.HeroLink_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 282: {
        if (version != 1) return false;
        if (count > input.remaining()/88) return false;
        for (uint32_t i=0; i<count; ++i) { HeroConfig row; if (!read(input,row)) return false; out.HeroConfig_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 283: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { PerseusDefinition row; if (!read(input,row)) return false; out.PerseusDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 284: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { LeoDefinition row; if (!read(input,row)) return false; out.LeoDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 285: {
        if (version != 1) return false;
        if (count > input.remaining()/8) return false;
        for (uint32_t i=0; i<count; ++i) { GeminiDefinition row; if (!read(input,row)) return false; out.GeminiDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 286: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { HerculesDefinition row; if (!read(input,row)) return false; out.HerculesDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 320: {
        if (version != 1) return false;
        if (count > input.remaining()/220) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusBodyDefinition row; if (!read(input,row)) return false; out.CentaurusBodyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 321: {
        if (version != 1) return false;
        if (count > input.remaining()/40) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusVolleyDefinition row; if (!read(input,row)) return false; out.CentaurusVolleyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 322: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusRearDefinition row; if (!read(input,row)) return false; out.CentaurusRearDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 323: {
        if (version != 1) return false;
        if (count > input.remaining()/132) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusRainDefinition row; if (!read(input,row)) return false; out.CentaurusRainDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 324: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusPowerDefinition row; if (!read(input,row)) return false; out.CentaurusPowerDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 325: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusStompDefinition row; if (!read(input,row)) return false; out.CentaurusStompDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 326: {
        if (version != 1) return false;
        if (count > input.remaining()/122) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusStompFoot row; if (!read(input,row)) return false; out.CentaurusStompFoot_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 327: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusFanDefinition row; if (!read(input,row)) return false; out.CentaurusFanDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 328: {
        if (version != 1) return false;
        if (count > input.remaining()/132) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusShowerDefinition row; if (!read(input,row)) return false; out.CentaurusShowerDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 329: {
        if (version != 1) return false;
        if (count > input.remaining()/84) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusSailDefinition row; if (!read(input,row)) return false; out.CentaurusSailDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 330: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { CentaurusComboDefinition row; if (!read(input,row)) return false; out.CentaurusComboDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 340: {
        if (version != 1) return false;
        if (count > input.remaining()/164) return false;
        for (uint32_t i=0; i<count; ++i) { CanisBodyDefinition row; if (!read(input,row)) return false; out.CanisBodyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 341: {
        if (version != 1) return false;
        if (count > input.remaining()/140) return false;
        for (uint32_t i=0; i<count; ++i) { CanisFlameDefinition row; if (!read(input,row)) return false; out.CanisFlameDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 342: {
        if (version != 1) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { CanisCommandDefinition row; if (!read(input,row)) return false; out.CanisCommandDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 343: {
        if (version != 1) return false;
        if (count > input.remaining()/128) return false;
        for (uint32_t i=0; i<count; ++i) { CanisHowlDefinition row; if (!read(input,row)) return false; out.CanisHowlDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 344: {
        if (version != 1) return false;
        if (count > input.remaining()/64) return false;
        for (uint32_t i=0; i<count; ++i) { CanisPounceDefinition row; if (!read(input,row)) return false; out.CanisPounceDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 345: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { CanisSiriusDefinition row; if (!read(input,row)) return false; out.CanisSiriusDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 346: {
        if (version != 1) return false;
        if (count > input.remaining()/224) return false;
        for (uint32_t i=0; i<count; ++i) { CanisBayDefinition row; if (!read(input,row)) return false; out.CanisBayDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 347: {
        if (version != 1) return false;
        if (count > input.remaining()/132) return false;
        for (uint32_t i=0; i<count; ++i) { CanisBlazeDefinition row; if (!read(input,row)) return false; out.CanisBlazeDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 348: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { CanisStreamDefinition row; if (!read(input,row)) return false; out.CanisStreamDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 349: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { CanisHuntDefinition row; if (!read(input,row)) return false; out.CanisHuntDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 350: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { CanisHuntPounceDefinition row; if (!read(input,row)) return false; out.CanisHuntPounceDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 351: {
        if (version != 1) return false;
        if (count > input.remaining()/148) return false;
        for (uint32_t i=0; i<count; ++i) { CanisNovaDefinition row; if (!read(input,row)) return false; out.CanisNovaDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 352: {
        if (version != 1) return false;
        if (count > input.remaining()/60) return false;
        for (uint32_t i=0; i<count; ++i) { CanisRelayDefinition row; if (!read(input,row)) return false; out.CanisRelayDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 353: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { CanisSiriusFlameDefinition row; if (!read(input,row)) return false; out.CanisSiriusFlameDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 370: {
        if (version != 1) return false;
        if (count > input.remaining()/172) return false;
        for (uint32_t i=0; i<count; ++i) { HydraBodyDefinition row; if (!read(input,row)) return false; out.HydraBodyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 371: {
        if (version != 1) return false;
        if (count > input.remaining()/80) return false;
        for (uint32_t i=0; i<count; ++i) { HydraRegrowDefinition row; if (!read(input,row)) return false; out.HydraRegrowDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 372: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { HydraNormalDefinition row; if (!read(input,row)) return false; out.HydraNormalDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 373: {
        if (version != 1) return false;
        if (count > input.remaining()/92) return false;
        for (uint32_t i=0; i<count; ++i) { HydraSwimDefinition row; if (!read(input,row)) return false; out.HydraSwimDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 374: {
        if (version != 1) return false;
        if (count > input.remaining()/49) return false;
        for (uint32_t i=0; i<count; ++i) { HydraNormalGate row; if (!read(input,row)) return false; out.HydraNormalGate_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 375: {
        if (version != 1) return false;
        if (count > input.remaining()/1408) return false;
        for (uint32_t i=0; i<count; ++i) { HydraSquadDefinition row; if (!read(input,row)) return false; out.HydraSquadDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 376: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { HydraSweepDefinition row; if (!read(input,row)) return false; out.HydraSweepDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 377: {
        if (version != 1) return false;
        if (count > input.remaining()/40) return false;
        for (uint32_t i=0; i<count; ++i) { HydraBoltDefinition row; if (!read(input,row)) return false; out.HydraBoltDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 378: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { HydraFixedBeamDefinition row; if (!read(input,row)) return false; out.HydraFixedBeamDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 379: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { HydraWindBladesDefinition row; if (!read(input,row)) return false; out.HydraWindBladesDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 380: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { HydraCurveDefinition row; if (!read(input,row)) return false; out.HydraCurveDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 387: {
        if (version != 1) return false;
        if (count > input.remaining()/42) return false;
        for (uint32_t i=0; i<count; ++i) { HydraMajorDefinition row; if (!read(input,row)) return false; out.HydraMajorDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 381: {
        if (version != 1) return false;
        if (count > input.remaining()/68) return false;
        for (uint32_t i=0; i<count; ++i) { HydraGridDefinition row; if (!read(input,row)) return false; out.HydraGridDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 384: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { HydraGridLayout row; if (!read(input,row)) return false; out.HydraGridLayout_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 385: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { HydraGridSlot row; if (!read(input,row)) return false; out.HydraGridSlot_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 386: {
        if (version != 1) return false;
        if (count > input.remaining()/28) return false;
        for (uint32_t i=0; i<count; ++i) { HydraGridPath row; if (!read(input,row)) return false; out.HydraGridPath_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 390: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { HydraRubbleDefinition row; if (!read(input,row)) return false; out.HydraRubbleDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 382: {
        if (version != 1) return false;
        if (count > input.remaining()/56) return false;
        for (uint32_t i=0; i<count; ++i) { HydraPincerDefinition row; if (!read(input,row)) return false; out.HydraPincerDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 392: {
        if (version != 1) return false;
        if (count > input.remaining()/44) return false;
        for (uint32_t i=0; i<count; ++i) { HydraTornadoDefinition row; if (!read(input,row)) return false; out.HydraTornadoDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 393: {
        if (version != 1) return false;
        if (count > input.remaining()/72) return false;
        for (uint32_t i=0; i<count; ++i) { HydraShatterDefinition row; if (!read(input,row)) return false; out.HydraShatterDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 403: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { HydraThunderDefinition row; if (!read(input,row)) return false; out.HydraThunderDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 383: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { HydraWindBandDefinition row; if (!read(input,row)) return false; out.HydraWindBandDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 404: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { HydraNorthDefinition row; if (!read(input,row)) return false; out.HydraNorthDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 405: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { HydraSequenceDefinition row; if (!read(input,row)) return false; out.HydraSequenceDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 406: {
        if (version != 1) return false;
        if (count > input.remaining()/72) return false;
        for (uint32_t i=0; i<count; ++i) { HydraSwarmDefinition row; if (!read(input,row)) return false; out.HydraSwarmDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 430: {
        if (version != 1) return false;
        if (count > input.remaining()/108) return false;
        for (uint32_t i=0; i<count; ++i) { DracoBodyDefinition row; if (!read(input,row)) return false; out.DracoBodyDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 431: {
        if (version != 1) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { DracoCycleDefinition row; if (!read(input,row)) return false; out.DracoCycleDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 432: {
        if (version != 1) return false;
        if (count > input.remaining()/13) return false;
        for (uint32_t i=0; i<count; ++i) { DracoCycleCandidate row; if (!read(input,row)) return false; out.DracoCycleCandidate_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 433: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { DracoBiteDefinition row; if (!read(input,row)) return false; out.DracoBiteDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 434: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { DracoBreathDefinition row; if (!read(input,row)) return false; out.DracoBreathDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 435: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { DracoChargeDefinition row; if (!read(input,row)) return false; out.DracoChargeDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 436: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { DracoLeapDefinition row; if (!read(input,row)) return false; out.DracoLeapDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 437: {
        if (version != 1) return false;
        if (count > input.remaining()/24) return false;
        for (uint32_t i=0; i<count; ++i) { DracoTailSlamDefinition row; if (!read(input,row)) return false; out.DracoTailSlamDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 438: {
        if (version != 1) return false;
        if (count > input.remaining()/16) return false;
        for (uint32_t i=0; i<count; ++i) { DracoTailSweepDefinition row; if (!read(input,row)) return false; out.DracoTailSweepDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 439: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { DracoStarFanDefinition row; if (!read(input,row)) return false; out.DracoStarFanDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 440: {
        if (version != 1) return false;
        if (count > input.remaining()/32) return false;
        for (uint32_t i=0; i<count; ++i) { DracoMeteorDefinition row; if (!read(input,row)) return false; out.DracoMeteorDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 441: {
        if (version != 1) return false;
        if (count > input.remaining()/68) return false;
        for (uint32_t i=0; i<count; ++i) { DracoRiftsDefinition row; if (!read(input,row)) return false; out.DracoRiftsDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 443: {
        if (version != 1) return false;
        if (count > input.remaining()/48) return false;
        for (uint32_t i=0; i<count; ++i) { DracoPicaroWallDefinition row; if (!read(input,row)) return false; out.DracoPicaroWallDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 446: {
        if (version != 1) return false;
        if (count > input.remaining()/12) return false;
        for (uint32_t i=0; i<count; ++i) { DracoPicaroWallCandidate row; if (!read(input,row)) return false; out.DracoPicaroWallCandidate_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 444: {
        if (version != 1) return false;
        if (count > input.remaining()/88) return false;
        for (uint32_t i=0; i<count; ++i) { DracoSpiralDefinition row; if (!read(input,row)) return false; out.DracoSpiralDefinition_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    default: return false;
    }
}
inline bool validate_references(const ContentRecords &data) {
    std::unordered_set<uint32_t> RunConfig_ids;
    for (const auto &row:data.RunConfig_rows) if (!RunConfig_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> StringEntry_ids;
    for (const auto &row:data.StringEntry_rows) if (!StringEntry_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DefinitionIndex_ids;
    for (const auto &row:data.DefinitionIndex_rows) if (!DefinitionIndex_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> EnemyRecord_ids;
    for (const auto &row:data.EnemyRecord_rows) if (!EnemyRecord_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LoadoutDefinition_ids;
    for (const auto &row:data.LoadoutDefinition_rows) if (!LoadoutDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HeroDefinition_ids;
    for (const auto &row:data.HeroDefinition_rows) if (!HeroDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FieldDefinition_ids;
    for (const auto &row:data.FieldDefinition_rows) if (!FieldDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationDefinition_ids;
    for (const auto &row:data.PopulationDefinition_rows) if (!PopulationDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FormationDefinition_ids;
    for (const auto &row:data.FormationDefinition_rows) if (!FormationDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowDefinition_ids;
    for (const auto &row:data.BossFlowDefinition_rows) if (!BossFlowDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> TechniqueDefinition_ids;
    for (const auto &row:data.TechniqueDefinition_rows) if (!TechniqueDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ResourceKey_ids;
    for (const auto &row:data.ResourceKey_rows) if (!ResourceKey_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ForwardDefinition_ids;
    for (const auto &row:data.ForwardDefinition_rows) if (!ForwardDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BiteDefinition_ids;
    for (const auto &row:data.BiteDefinition_rows) if (!BiteDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LifecycleDefinition_ids;
    for (const auto &row:data.LifecycleDefinition_rows) if (!LifecycleDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> EnemyTuningValue_ids;
    for (const auto &row:data.EnemyTuningValue_rows) if (!EnemyTuningValue_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ContactDefinition_ids;
    for (const auto &row:data.ContactDefinition_rows) if (!ContactDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HostileDefinition_ids;
    for (const auto &row:data.HostileDefinition_rows) if (!HostileDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BeamDefinition_ids;
    for (const auto &row:data.BeamDefinition_rows) if (!BeamDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FriendShotDefinition_ids;
    for (const auto &row:data.FriendShotDefinition_rows) if (!FriendShotDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> WaveDefinition_ids;
    for (const auto &row:data.WaveDefinition_rows) if (!WaveDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> WallDefinition_ids;
    for (const auto &row:data.WallDefinition_rows) if (!WallDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> SlashDefinition_ids;
    for (const auto &row:data.SlashDefinition_rows) if (!SlashDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BoltDefinition_ids;
    for (const auto &row:data.BoltDefinition_rows) if (!BoltDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LightArrowDefinition_ids;
    for (const auto &row:data.LightArrowDefinition_rows) if (!LightArrowDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> StarBoltDefinition_ids;
    for (const auto &row:data.StarBoltDefinition_rows) if (!StarBoltDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RingHoldDefinition_ids;
    for (const auto &row:data.RingHoldDefinition_rows) if (!RingHoldDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LumpDefinition_ids;
    for (const auto &row:data.LumpDefinition_rows) if (!LumpDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FriendDebrisDefinition_ids;
    for (const auto &row:data.FriendDebrisDefinition_rows) if (!FriendDebrisDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FriendHullDefinition_ids;
    for (const auto &row:data.FriendHullDefinition_rows) if (!FriendHullDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FriendHullLook_ids;
    for (const auto &row:data.FriendHullLook_rows) if (!FriendHullLook_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FriendSawPoint_ids;
    for (const auto &row:data.FriendSawPoint_rows) if (!FriendSawPoint_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ZoneDefinition_ids;
    for (const auto &row:data.ZoneDefinition_rows) if (!ZoneDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FloodDefinition_ids;
    for (const auto &row:data.FloodDefinition_rows) if (!FloodDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LightLanceDefinition_ids;
    for (const auto &row:data.LightLanceDefinition_rows) if (!LightLanceDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ShellDefinition_ids;
    for (const auto &row:data.ShellDefinition_rows) if (!ShellDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ShellSource_ids;
    for (const auto &row:data.ShellSource_rows) if (!ShellSource_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BudgetPhase_ids;
    for (const auto &row:data.BudgetPhase_rows) if (!BudgetPhase_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationPhase_ids;
    for (const auto &row:data.PopulationPhase_rows) if (!PopulationPhase_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationMix_ids;
    for (const auto &row:data.PopulationMix_rows) if (!PopulationMix_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationCurve_ids;
    for (const auto &row:data.PopulationCurve_rows) if (!PopulationCurve_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationPoint_ids;
    for (const auto &row:data.PopulationPoint_rows) if (!PopulationPoint_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationWindow_ids;
    for (const auto &row:data.PopulationWindow_rows) if (!PopulationWindow_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationType_ids;
    for (const auto &row:data.PopulationType_rows) if (!PopulationType_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FormationEntry_ids;
    for (const auto &row:data.FormationEntry_rows) if (!FormationEntry_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FormationLayout_ids;
    for (const auto &row:data.FormationLayout_rows) if (!FormationLayout_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FormationType_ids;
    for (const auto &row:data.FormationType_rows) if (!FormationType_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FormationMarker_ids;
    for (const auto &row:data.FormationMarker_rows) if (!FormationMarker_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationClip_ids;
    for (const auto &row:data.PopulationClip_rows) if (!PopulationClip_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationClipType_ids;
    for (const auto &row:data.PopulationClipType_rows) if (!PopulationClipType_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PopulationClipFormation_ids;
    for (const auto &row:data.PopulationClipFormation_rows) if (!PopulationClipFormation_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DeathChainDefinition_ids;
    for (const auto &row:data.DeathChainDefinition_rows) if (!DeathChainDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> EncounterDefinition_ids;
    for (const auto &row:data.EncounterDefinition_rows) if (!EncounterDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> EncounterPattern_ids;
    for (const auto &row:data.EncounterPattern_rows) if (!EncounterPattern_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> EncounterPoint_ids;
    for (const auto &row:data.EncounterPoint_rows) if (!EncounterPoint_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> EncounterRegion_ids;
    for (const auto &row:data.EncounterRegion_rows) if (!EncounterRegion_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> EncounterPhase_ids;
    for (const auto &row:data.EncounterPhase_rows) if (!EncounterPhase_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ProgressionDefinition_ids;
    for (const auto &row:data.ProgressionDefinition_rows) if (!ProgressionDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LoadoutAsset_ids;
    for (const auto &row:data.LoadoutAsset_rows) if (!LoadoutAsset_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxDefinition_ids;
    for (const auto &row:data.PostMaxDefinition_rows) if (!PostMaxDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxTarget_ids;
    for (const auto &row:data.PostMaxTarget_rows) if (!PostMaxTarget_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxInterval_ids;
    for (const auto &row:data.PostMaxInterval_rows) if (!PostMaxInterval_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HoundDefinition_ids;
    for (const auto &row:data.HoundDefinition_rows) if (!HoundDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ShieldDefinition_ids;
    for (const auto &row:data.ShieldDefinition_rows) if (!ShieldDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> GunnerDefinition_ids;
    for (const auto &row:data.GunnerDefinition_rows) if (!GunnerDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BeamerDefinition_ids;
    for (const auto &row:data.BeamerDefinition_rows) if (!BeamerDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> MissileEnemyDefinition_ids;
    for (const auto &row:data.MissileEnemyDefinition_rows) if (!MissileEnemyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RocketDefinition_ids;
    for (const auto &row:data.RocketDefinition_rows) if (!RocketDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DriftDefinition_ids;
    for (const auto &row:data.DriftDefinition_rows) if (!DriftDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PartDefinition_ids;
    for (const auto &row:data.PartDefinition_rows) if (!PartDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DashDefinition_ids;
    for (const auto &row:data.DashDefinition_rows) if (!DashDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BattleshipDefinition_ids;
    for (const auto &row:data.BattleshipDefinition_rows) if (!BattleshipDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> SniperDefinition_ids;
    for (const auto &row:data.SniperDefinition_rows) if (!SniperDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> MarlinDefinition_ids;
    for (const auto &row:data.MarlinDefinition_rows) if (!MarlinDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PulserDefinition_ids;
    for (const auto &row:data.PulserDefinition_rows) if (!PulserDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DolphinDefinition_ids;
    for (const auto &row:data.DolphinDefinition_rows) if (!DolphinDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LynxDefinition_ids;
    for (const auto &row:data.LynxDefinition_rows) if (!LynxDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> SoldierDefinition_ids;
    for (const auto &row:data.SoldierDefinition_rows) if (!SoldierDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> AurigaDefinition_ids;
    for (const auto &row:data.AurigaDefinition_rows) if (!AurigaDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ClockDefinition_ids;
    for (const auto &row:data.ClockDefinition_rows) if (!ClockDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ReticleDefinition_ids;
    for (const auto &row:data.ReticleDefinition_rows) if (!ReticleDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> AquariusDefinition_ids;
    for (const auto &row:data.AquariusDefinition_rows) if (!AquariusDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CrossEnemyDefinition_ids;
    for (const auto &row:data.CrossEnemyDefinition_rows) if (!CrossEnemyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BomberDefinition_ids;
    for (const auto &row:data.BomberDefinition_rows) if (!BomberDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PhoenixDefinition_ids;
    for (const auto &row:data.PhoenixDefinition_rows) if (!PhoenixDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> AquilaDefinition_ids;
    for (const auto &row:data.AquilaDefinition_rows) if (!AquilaDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> SplitDefinition_ids;
    for (const auto &row:data.SplitDefinition_rows) if (!SplitDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DefenderDefinition_ids;
    for (const auto &row:data.DefenderDefinition_rows) if (!DefenderDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CrabDefinition_ids;
    for (const auto &row:data.CrabDefinition_rows) if (!CrabDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CrowDefinition_ids;
    for (const auto &row:data.CrowDefinition_rows) if (!CrowDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CepheusDefinition_ids;
    for (const auto &row:data.CepheusDefinition_rows) if (!CepheusDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PumpDefinition_ids;
    for (const auto &row:data.PumpDefinition_rows) if (!PumpDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> TriangleStarDefinition_ids;
    for (const auto &row:data.TriangleStarDefinition_rows) if (!TriangleStarDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CoronaDefinition_ids;
    for (const auto &row:data.CoronaDefinition_rows) if (!CoronaDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CoronaType_ids;
    for (const auto &row:data.CoronaType_rows) if (!CoronaType_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RulerDefinition_ids;
    for (const auto &row:data.RulerDefinition_rows) if (!RulerDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> TriangleDefinition_ids;
    for (const auto &row:data.TriangleDefinition_rows) if (!TriangleDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FieldBodyDefinition_ids;
    for (const auto &row:data.FieldBodyDefinition_rows) if (!FieldBodyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> MoonDefinition_ids;
    for (const auto &row:data.MoonDefinition_rows) if (!MoonDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RockFieldDefinition_ids;
    for (const auto &row:data.RockFieldDefinition_rows) if (!RockFieldDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> GravityDefinition_ids;
    for (const auto &row:data.GravityDefinition_rows) if (!GravityDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> WarpDefinition_ids;
    for (const auto &row:data.WarpDefinition_rows) if (!WarpDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CometDefinition_ids;
    for (const auto &row:data.CometDefinition_rows) if (!CometDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> NumericTraitLevel_ids;
    for (const auto &row:data.NumericTraitLevel_rows) if (!NumericTraitLevel_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxChargeDefinition_ids;
    for (const auto &row:data.PostMaxChargeDefinition_rows) if (!PostMaxChargeDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxCritDefinition_ids;
    for (const auto &row:data.PostMaxCritDefinition_rows) if (!PostMaxCritDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxMotionDefinition_ids;
    for (const auto &row:data.PostMaxMotionDefinition_rows) if (!PostMaxMotionDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxWeaponPowerDefinition_ids;
    for (const auto &row:data.PostMaxWeaponPowerDefinition_rows) if (!PostMaxWeaponPowerDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxPickupDefinition_ids;
    for (const auto &row:data.PostMaxPickupDefinition_rows) if (!PostMaxPickupDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PostMaxDrawDefinition_ids;
    for (const auto &row:data.PostMaxDrawDefinition_rows) if (!PostMaxDrawDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ScatterDefinition_ids;
    for (const auto &row:data.ScatterDefinition_rows) if (!ScatterDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ScatterPostDefinition_ids;
    for (const auto &row:data.ScatterPostDefinition_rows) if (!ScatterPostDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RearDefinition_ids;
    for (const auto &row:data.RearDefinition_rows) if (!RearDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RearPostDefinition_ids;
    for (const auto &row:data.RearPostDefinition_rows) if (!RearPostDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BarrierDefinition_ids;
    for (const auto &row:data.BarrierDefinition_rows) if (!BarrierDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BarrierPostDefinition_ids;
    for (const auto &row:data.BarrierPostDefinition_rows) if (!BarrierPostDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FullChargeDefinition_ids;
    for (const auto &row:data.FullChargeDefinition_rows) if (!FullChargeDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RampageDefinition_ids;
    for (const auto &row:data.RampageDefinition_rows) if (!RampageDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DuplicatorDefinition_ids;
    for (const auto &row:data.DuplicatorDefinition_rows) if (!DuplicatorDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> EndBlastDefinition_ids;
    for (const auto &row:data.EndBlastDefinition_rows) if (!EndBlastDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RunUpDefinition_ids;
    for (const auto &row:data.RunUpDefinition_rows) if (!RunUpDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> MinesDefinition_ids;
    for (const auto &row:data.MinesDefinition_rows) if (!MinesDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> VortexDefinition_ids;
    for (const auto &row:data.VortexDefinition_rows) if (!VortexDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CritBeamDefinition_ids;
    for (const auto &row:data.CritBeamDefinition_rows) if (!CritBeamDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> KnockbackDefinition_ids;
    for (const auto &row:data.KnockbackDefinition_rows) if (!KnockbackDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ContactWaveDefinition_ids;
    for (const auto &row:data.ContactWaveDefinition_rows) if (!ContactWaveDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> SonicDefinition_ids;
    for (const auto &row:data.SonicDefinition_rows) if (!SonicDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> ContactArcDefinition_ids;
    for (const auto &row:data.ContactArcDefinition_rows) if (!ContactArcDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> KillSonicDefinition_ids;
    for (const auto &row:data.KillSonicDefinition_rows) if (!KillSonicDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> MassTowDefinition_ids;
    for (const auto &row:data.MassTowDefinition_rows) if (!MassTowDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BipolarDefinition_ids;
    for (const auto &row:data.BipolarDefinition_rows) if (!BipolarDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> InterceptorDefinition_ids;
    for (const auto &row:data.InterceptorDefinition_rows) if (!InterceptorDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DashRangeDroneDefinition_ids;
    for (const auto &row:data.DashRangeDroneDefinition_rows) if (!DashRangeDroneDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> AfterimageDefinition_ids;
    for (const auto &row:data.AfterimageDefinition_rows) if (!AfterimageDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> FlashSlashDefinition_ids;
    for (const auto &row:data.FlashSlashDefinition_rows) if (!FlashSlashDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossDefinition_ids;
    for (const auto &row:data.BossDefinition_rows) if (!BossDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossTechniqueDefinition_ids;
    for (const auto &row:data.BossTechniqueDefinition_rows) if (!BossTechniqueDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossTechniqueStage_ids;
    for (const auto &row:data.BossTechniqueStage_rows) if (!BossTechniqueStage_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossBodyDefinition_ids;
    for (const auto &row:data.BossBodyDefinition_rows) if (!BossBodyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFinishDefinition_ids;
    for (const auto &row:data.BossFinishDefinition_rows) if (!BossFinishDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowProgram_ids;
    for (const auto &row:data.BossFlowProgram_rows) if (!BossFlowProgram_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowSection_ids;
    for (const auto &row:data.BossFlowSection_rows) if (!BossFlowSection_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowCondition_ids;
    for (const auto &row:data.BossFlowCondition_rows) if (!BossFlowCondition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowNode_ids;
    for (const auto &row:data.BossFlowNode_rows) if (!BossFlowNode_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowChild_ids;
    for (const auto &row:data.BossFlowChild_rows) if (!BossFlowChild_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowAction_ids;
    for (const auto &row:data.BossFlowAction_rows) if (!BossFlowAction_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowFilter_ids;
    for (const auto &row:data.BossFlowFilter_rows) if (!BossFlowFilter_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowWeight_ids;
    for (const auto &row:data.BossFlowWeight_rows) if (!BossFlowWeight_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> BossFlowForbidden_ids;
    for (const auto &row:data.BossFlowForbidden_rows) if (!BossFlowForbidden_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HeroStar_ids;
    for (const auto &row:data.HeroStar_rows) if (!HeroStar_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HeroLink_ids;
    for (const auto &row:data.HeroLink_rows) if (!HeroLink_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HeroConfig_ids;
    for (const auto &row:data.HeroConfig_rows) if (!HeroConfig_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> PerseusDefinition_ids;
    for (const auto &row:data.PerseusDefinition_rows) if (!PerseusDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LeoDefinition_ids;
    for (const auto &row:data.LeoDefinition_rows) if (!LeoDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> GeminiDefinition_ids;
    for (const auto &row:data.GeminiDefinition_rows) if (!GeminiDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HerculesDefinition_ids;
    for (const auto &row:data.HerculesDefinition_rows) if (!HerculesDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusBodyDefinition_ids;
    for (const auto &row:data.CentaurusBodyDefinition_rows) if (!CentaurusBodyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusVolleyDefinition_ids;
    for (const auto &row:data.CentaurusVolleyDefinition_rows) if (!CentaurusVolleyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusRearDefinition_ids;
    for (const auto &row:data.CentaurusRearDefinition_rows) if (!CentaurusRearDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusRainDefinition_ids;
    for (const auto &row:data.CentaurusRainDefinition_rows) if (!CentaurusRainDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusPowerDefinition_ids;
    for (const auto &row:data.CentaurusPowerDefinition_rows) if (!CentaurusPowerDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusStompDefinition_ids;
    for (const auto &row:data.CentaurusStompDefinition_rows) if (!CentaurusStompDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusStompFoot_ids;
    for (const auto &row:data.CentaurusStompFoot_rows) if (!CentaurusStompFoot_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusFanDefinition_ids;
    for (const auto &row:data.CentaurusFanDefinition_rows) if (!CentaurusFanDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusShowerDefinition_ids;
    for (const auto &row:data.CentaurusShowerDefinition_rows) if (!CentaurusShowerDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusSailDefinition_ids;
    for (const auto &row:data.CentaurusSailDefinition_rows) if (!CentaurusSailDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CentaurusComboDefinition_ids;
    for (const auto &row:data.CentaurusComboDefinition_rows) if (!CentaurusComboDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisBodyDefinition_ids;
    for (const auto &row:data.CanisBodyDefinition_rows) if (!CanisBodyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisFlameDefinition_ids;
    for (const auto &row:data.CanisFlameDefinition_rows) if (!CanisFlameDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisCommandDefinition_ids;
    for (const auto &row:data.CanisCommandDefinition_rows) if (!CanisCommandDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisHowlDefinition_ids;
    for (const auto &row:data.CanisHowlDefinition_rows) if (!CanisHowlDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisPounceDefinition_ids;
    for (const auto &row:data.CanisPounceDefinition_rows) if (!CanisPounceDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisSiriusDefinition_ids;
    for (const auto &row:data.CanisSiriusDefinition_rows) if (!CanisSiriusDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisBayDefinition_ids;
    for (const auto &row:data.CanisBayDefinition_rows) if (!CanisBayDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisBlazeDefinition_ids;
    for (const auto &row:data.CanisBlazeDefinition_rows) if (!CanisBlazeDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisStreamDefinition_ids;
    for (const auto &row:data.CanisStreamDefinition_rows) if (!CanisStreamDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisHuntDefinition_ids;
    for (const auto &row:data.CanisHuntDefinition_rows) if (!CanisHuntDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisHuntPounceDefinition_ids;
    for (const auto &row:data.CanisHuntPounceDefinition_rows) if (!CanisHuntPounceDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisNovaDefinition_ids;
    for (const auto &row:data.CanisNovaDefinition_rows) if (!CanisNovaDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisRelayDefinition_ids;
    for (const auto &row:data.CanisRelayDefinition_rows) if (!CanisRelayDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> CanisSiriusFlameDefinition_ids;
    for (const auto &row:data.CanisSiriusFlameDefinition_rows) if (!CanisSiriusFlameDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraBodyDefinition_ids;
    for (const auto &row:data.HydraBodyDefinition_rows) if (!HydraBodyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraRegrowDefinition_ids;
    for (const auto &row:data.HydraRegrowDefinition_rows) if (!HydraRegrowDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraNormalDefinition_ids;
    for (const auto &row:data.HydraNormalDefinition_rows) if (!HydraNormalDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraSwimDefinition_ids;
    for (const auto &row:data.HydraSwimDefinition_rows) if (!HydraSwimDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraNormalGate_ids;
    for (const auto &row:data.HydraNormalGate_rows) if (!HydraNormalGate_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraSquadDefinition_ids;
    for (const auto &row:data.HydraSquadDefinition_rows) if (!HydraSquadDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraSweepDefinition_ids;
    for (const auto &row:data.HydraSweepDefinition_rows) if (!HydraSweepDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraBoltDefinition_ids;
    for (const auto &row:data.HydraBoltDefinition_rows) if (!HydraBoltDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraFixedBeamDefinition_ids;
    for (const auto &row:data.HydraFixedBeamDefinition_rows) if (!HydraFixedBeamDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraWindBladesDefinition_ids;
    for (const auto &row:data.HydraWindBladesDefinition_rows) if (!HydraWindBladesDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraCurveDefinition_ids;
    for (const auto &row:data.HydraCurveDefinition_rows) if (!HydraCurveDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraMajorDefinition_ids;
    for (const auto &row:data.HydraMajorDefinition_rows) if (!HydraMajorDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraGridDefinition_ids;
    for (const auto &row:data.HydraGridDefinition_rows) if (!HydraGridDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraGridLayout_ids;
    for (const auto &row:data.HydraGridLayout_rows) if (!HydraGridLayout_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraGridSlot_ids;
    for (const auto &row:data.HydraGridSlot_rows) if (!HydraGridSlot_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraGridPath_ids;
    for (const auto &row:data.HydraGridPath_rows) if (!HydraGridPath_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraRubbleDefinition_ids;
    for (const auto &row:data.HydraRubbleDefinition_rows) if (!HydraRubbleDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraPincerDefinition_ids;
    for (const auto &row:data.HydraPincerDefinition_rows) if (!HydraPincerDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraTornadoDefinition_ids;
    for (const auto &row:data.HydraTornadoDefinition_rows) if (!HydraTornadoDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraShatterDefinition_ids;
    for (const auto &row:data.HydraShatterDefinition_rows) if (!HydraShatterDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraThunderDefinition_ids;
    for (const auto &row:data.HydraThunderDefinition_rows) if (!HydraThunderDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraWindBandDefinition_ids;
    for (const auto &row:data.HydraWindBandDefinition_rows) if (!HydraWindBandDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraNorthDefinition_ids;
    for (const auto &row:data.HydraNorthDefinition_rows) if (!HydraNorthDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraSequenceDefinition_ids;
    for (const auto &row:data.HydraSequenceDefinition_rows) if (!HydraSequenceDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> HydraSwarmDefinition_ids;
    for (const auto &row:data.HydraSwarmDefinition_rows) if (!HydraSwarmDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoBodyDefinition_ids;
    for (const auto &row:data.DracoBodyDefinition_rows) if (!DracoBodyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoCycleDefinition_ids;
    for (const auto &row:data.DracoCycleDefinition_rows) if (!DracoCycleDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoCycleCandidate_ids;
    for (const auto &row:data.DracoCycleCandidate_rows) if (!DracoCycleCandidate_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoBiteDefinition_ids;
    for (const auto &row:data.DracoBiteDefinition_rows) if (!DracoBiteDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoBreathDefinition_ids;
    for (const auto &row:data.DracoBreathDefinition_rows) if (!DracoBreathDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoChargeDefinition_ids;
    for (const auto &row:data.DracoChargeDefinition_rows) if (!DracoChargeDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoLeapDefinition_ids;
    for (const auto &row:data.DracoLeapDefinition_rows) if (!DracoLeapDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoTailSlamDefinition_ids;
    for (const auto &row:data.DracoTailSlamDefinition_rows) if (!DracoTailSlamDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoTailSweepDefinition_ids;
    for (const auto &row:data.DracoTailSweepDefinition_rows) if (!DracoTailSweepDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoStarFanDefinition_ids;
    for (const auto &row:data.DracoStarFanDefinition_rows) if (!DracoStarFanDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoMeteorDefinition_ids;
    for (const auto &row:data.DracoMeteorDefinition_rows) if (!DracoMeteorDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoRiftsDefinition_ids;
    for (const auto &row:data.DracoRiftsDefinition_rows) if (!DracoRiftsDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoPicaroWallDefinition_ids;
    for (const auto &row:data.DracoPicaroWallDefinition_rows) if (!DracoPicaroWallDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoPicaroWallCandidate_ids;
    for (const auto &row:data.DracoPicaroWallCandidate_rows) if (!DracoPicaroWallCandidate_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> DracoSpiralDefinition_ids;
    for (const auto &row:data.DracoSpiralDefinition_rows) if (!DracoSpiralDefinition_ids.insert(row.id).second) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.ship_visual)) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.shot_visual)) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.crystal_visual)) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.coin_visual)) return false;
    for (const auto &row:data.RunConfig_rows) if (!ResourceKey_ids.count(row.cannon_visual)) return false;
    for (const auto &row:data.DefinitionIndex_rows) if (!StringEntry_ids.count(row.id)) return false;
    for (const auto &row:data.DefinitionIndex_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.EnemyRecord_rows) if (!StringEntry_ids.count(row.id)) return false;
    for (const auto &row:data.EnemyRecord_rows) if (!ResourceKey_ids.count(row.visual_id)) return false;
    for (const auto &row:data.ForwardDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.BiteDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.BiteDefinition_rows) if (!ResourceKey_ids.count(row.visual_key)) return false;
    for (const auto &row:data.EnemyTuningValue_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.HostileDefinition_rows) if (!ResourceKey_ids.count(row.visual)) return false;
    for (const auto &row:data.HostileDefinition_rows) if (!ResourceKey_ids.count(row.stone_visual)) return false;
    for (const auto &row:data.HostileDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.BeamDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.FriendShotDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.WaveDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.WallDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.SlashDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.BoltDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.LightArrowDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.StarBoltDefinition_rows) if (!ResourceKey_ids.count(row.visual)) return false;
    for (const auto &row:data.StarBoltDefinition_rows) if (!ResourceKey_ids.count(row.stone_visual)) return false;
    for (const auto &row:data.StarBoltDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.RingHoldDefinition_rows) if (!HostileDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.LumpDefinition_rows) if (!HostileDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.FriendDebrisDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.FriendHullDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.FriendHullLook_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.ZoneDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.FloodDefinition_rows) if (!BeamDefinition_ids.count(row.beam)) return false;
    for (const auto &row:data.ShellDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.ShellSource_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.PopulationMix_rows) if (!PopulationPhase_ids.count(row.phase)) return false;
    for (const auto &row:data.PopulationMix_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.PopulationCurve_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.PopulationPoint_rows) if (!PopulationCurve_ids.count(row.curve)) return false;
    for (const auto &row:data.PopulationType_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.FormationEntry_rows) if (!FormationDefinition_ids.count(row.formation)) return false;
    for (const auto &row:data.FormationLayout_rows) if (!FormationDefinition_ids.count(row.formation)) return false;
    for (const auto &row:data.FormationType_rows) if (!FormationLayout_ids.count(row.layout)) return false;
    for (const auto &row:data.FormationType_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.FormationMarker_rows) if (!FormationLayout_ids.count(row.layout)) return false;
    for (const auto &row:data.FormationMarker_rows) if (!FormationEntry_ids.count(row.entry)) return false;
    for (const auto &row:data.FormationMarker_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.PopulationClipType_rows) if (!PopulationClip_ids.count(row.clip)) return false;
    for (const auto &row:data.PopulationClipType_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.PopulationClipFormation_rows) if (!PopulationClip_ids.count(row.clip)) return false;
    for (const auto &row:data.PopulationClipFormation_rows) if (!FormationDefinition_ids.count(row.formation)) return false;
    for (const auto &row:data.DeathChainDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.EncounterPoint_rows) if (!EncounterPattern_ids.count(row.pattern)) return false;
    for (const auto &row:data.EncounterRegion_rows) if (!EncounterPattern_ids.count(row.pattern)) return false;
    for (const auto &row:data.LoadoutAsset_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.LoadoutAsset_rows) if (!ResourceKey_ids.count(row.asset)) return false;
    for (const auto &row:data.PostMaxTarget_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.PostMaxTarget_rows) if (!PostMaxDefinition_ids.count(row.effect)) return false;
    for (const auto &row:data.PostMaxInterval_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.HoundDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.ShieldDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.ShieldDefinition_rows) if (!HostileDefinition_ids.count(row.reflected)) return false;
    for (const auto &row:data.GunnerDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.BeamerDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.MissileEnemyDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.RocketDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.RocketDefinition_rows) if (!ContactDefinition_ids.count(row.contact)) return false;
    for (const auto &row:data.DriftDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.PartDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.DashDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.BattleshipDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.SniperDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.MarlinDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.PulserDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.DolphinDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.LynxDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.SoldierDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.AurigaDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.ClockDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.ReticleDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.AquariusDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.CrossEnemyDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.BomberDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.PhoenixDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.AquilaDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.SplitDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.SplitDefinition_rows) if (!EnemyRecord_ids.count(row.child)) return false;
    for (const auto &row:data.DefenderDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.CrabDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.CrowDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.CepheusDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.CepheusDefinition_rows) if (!EnemyRecord_ids.count(row.soldier)) return false;
    for (const auto &row:data.PumpDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.TriangleStarDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.CoronaDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.CoronaType_rows) if (!EnemyRecord_ids.count(row.owner)) return false;
    for (const auto &row:data.RulerDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.TriangleDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.TriangleDefinition_rows) if (!EnemyRecord_ids.count(row.star)) return false;
    for (const auto &row:data.FieldBodyDefinition_rows) if (!ResourceKey_ids.count(row.visual)) return false;
    for (const auto &row:data.MoonDefinition_rows) if (!ResourceKey_ids.count(row.visual)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!EnemyRecord_ids.count(row.meteor)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!EnemyRecord_ids.count(row.iron)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!EnemyRecord_ids.count(row.saw)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!ResourceKey_ids.count(row.meteor_visual_0)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!ResourceKey_ids.count(row.meteor_visual_1)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!ResourceKey_ids.count(row.meteor_visual_2)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!ResourceKey_ids.count(row.meteor_visual_3)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!ResourceKey_ids.count(row.meteor_visual_4)) return false;
    for (const auto &row:data.RockFieldDefinition_rows) if (!ResourceKey_ids.count(row.meteor_visual_5)) return false;
    for (const auto &row:data.NumericTraitLevel_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.PostMaxWeaponPowerDefinition_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.ScatterDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.RearDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.BarrierDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.FullChargeDefinition_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.RampageDefinition_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.DuplicatorDefinition_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.EndBlastDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.RunUpDefinition_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.MinesDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.VortexDefinition_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.CritBeamDefinition_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.KnockbackDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.ContactWaveDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.SonicDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.ContactArcDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.KillSonicDefinition_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.MassTowDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.BipolarDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.InterceptorDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.DashRangeDroneDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.AfterimageDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.FlashSlashDefinition_rows) if (!LoadoutDefinition_ids.count(row.weapon)) return false;
    for (const auto &row:data.BossTechniqueDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.BossTechniqueStage_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.BossBodyDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.BossBodyDefinition_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.BossFlowProgram_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.BossFlowSection_rows) if (!BossFlowProgram_ids.count(row.flow)) return false;
    for (const auto &row:data.BossFlowNode_rows) if (!BossFlowProgram_ids.count(row.flow)) return false;
    for (const auto &row:data.BossFlowChild_rows) if (!BossFlowNode_ids.count(row.parent)) return false;
    for (const auto &row:data.BossFlowChild_rows) if (!BossFlowNode_ids.count(row.child)) return false;
    for (const auto &row:data.BossFlowAction_rows) if (!BossFlowProgram_ids.count(row.flow)) return false;
    for (const auto &row:data.BossFlowAction_rows) if (!BossFlowNode_ids.count(row.node)) return false;
    for (const auto &row:data.BossFlowAction_rows) if (!BossFlowCondition_ids.count(row.condition)) return false;
    for (const auto &row:data.BossFlowFilter_rows) if (!BossFlowSection_ids.count(row.section)) return false;
    for (const auto &row:data.BossFlowWeight_rows) if (!BossFlowSection_ids.count(row.section)) return false;
    for (const auto &row:data.BossFlowForbidden_rows) if (!BossFlowSection_ids.count(row.section)) return false;
    for (const auto &row:data.HeroStar_rows) if (!HeroDefinition_ids.count(row.hero)) return false;
    for (const auto &row:data.HeroLink_rows) if (!HeroDefinition_ids.count(row.hero)) return false;
    for (const auto &row:data.PerseusDefinition_rows) if (!HeroDefinition_ids.count(row.hero)) return false;
    for (const auto &row:data.LeoDefinition_rows) if (!HeroDefinition_ids.count(row.hero)) return false;
    for (const auto &row:data.GeminiDefinition_rows) if (!HeroDefinition_ids.count(row.hero)) return false;
    for (const auto &row:data.HerculesDefinition_rows) if (!HeroDefinition_ids.count(row.hero)) return false;
    for (const auto &row:data.CentaurusBodyDefinition_rows) if (!BossBodyDefinition_ids.count(row.body)) return false;
    for (const auto &row:data.CentaurusBodyDefinition_rows) if (!EnemyRecord_ids.count(row.guard)) return false;
    for (const auto &row:data.CentaurusVolleyDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusVolleyDefinition_rows) if (!LightArrowDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.CentaurusRearDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusRainDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusRainDefinition_rows) if (!LightArrowDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.CentaurusPowerDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusPowerDefinition_rows) if (!LightArrowDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.CentaurusStompDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusStompFoot_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusFanDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusFanDefinition_rows) if (!LightArrowDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.CentaurusShowerDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusShowerDefinition_rows) if (!LightArrowDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.CentaurusSailDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusSailDefinition_rows) if (!LightArrowDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.CentaurusComboDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CentaurusComboDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.first)) return false;
    for (const auto &row:data.CentaurusComboDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.second)) return false;
    for (const auto &row:data.CanisBodyDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.CanisBodyDefinition_rows) if (!EnemyRecord_ids.count(row.hound)) return false;
    for (const auto &row:data.CanisFlameDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.CanisCommandDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisHowlDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisPounceDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisSiriusDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisSiriusDefinition_rows) if (!CanisFlameDefinition_ids.count(row.flame)) return false;
    for (const auto &row:data.CanisBayDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisBayDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.pounce)) return false;
    for (const auto &row:data.CanisBlazeDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisBlazeDefinition_rows) if (!CanisFlameDefinition_ids.count(row.flame)) return false;
    for (const auto &row:data.CanisStreamDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisHuntDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisHuntDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.stream)) return false;
    for (const auto &row:data.CanisHuntDefinition_rows) if (!CanisFlameDefinition_ids.count(row.flame)) return false;
    for (const auto &row:data.CanisHuntPounceDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisHuntPounceDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.stream)) return false;
    for (const auto &row:data.CanisHuntPounceDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.pounce)) return false;
    for (const auto &row:data.CanisNovaDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisRelayDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisRelayDefinition_rows) if (!CanisFlameDefinition_ids.count(row.hound_flame)) return false;
    for (const auto &row:data.CanisRelayDefinition_rows) if (!CanisFlameDefinition_ids.count(row.final_flame)) return false;
    for (const auto &row:data.CanisSiriusFlameDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.CanisSiriusFlameDefinition_rows) if (!CanisFlameDefinition_ids.count(row.flame)) return false;
    for (const auto &row:data.HydraBodyDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.HydraBodyDefinition_rows) if (!EnemyRecord_ids.count(row.bite)) return false;
    for (const auto &row:data.HydraBodyDefinition_rows) if (!EnemyRecord_ids.count(row.vortex)) return false;
    for (const auto &row:data.HydraBodyDefinition_rows) if (!EnemyRecord_ids.count(row.debris)) return false;
    for (const auto &row:data.HydraBodyDefinition_rows) if (!EnemyRecord_ids.count(row.beam)) return false;
    for (const auto &row:data.HydraBodyDefinition_rows) if (!EnemyRecord_ids.count(row.thunder)) return false;
    for (const auto &row:data.HydraRegrowDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.HydraNormalDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraSwimDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.HydraSwimDefinition_rows) if (!EnemyRecord_ids.count(row.immortal)) return false;
    for (const auto &row:data.HydraNormalGate_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraSquadDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.HydraSweepDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraBoltDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraFixedBeamDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraWindBladesDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraCurveDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraMajorDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraGridDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraGridLayout_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraGridSlot_rows) if (!HydraGridLayout_ids.count(row.layout)) return false;
    for (const auto &row:data.HydraGridPath_rows) if (!HydraGridLayout_ids.count(row.layout)) return false;
    for (const auto &row:data.HydraRubbleDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraRubbleDefinition_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.HydraPincerDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraTornadoDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraTornadoDefinition_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.HydraShatterDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraShatterDefinition_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.HydraThunderDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraWindBandDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraNorthDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraSequenceDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.HydraSwarmDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoBodyDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.DracoCycleDefinition_rows) if (!BossDefinition_ids.count(row.boss)) return false;
    for (const auto &row:data.DracoCycleCandidate_rows) if (!DracoCycleDefinition_ids.count(row.cycle)) return false;
    for (const auto &row:data.DracoCycleCandidate_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.DracoBiteDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoBreathDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoBreathDefinition_rows) if (!EnemyRecord_ids.count(row.rock_enemy)) return false;
    for (const auto &row:data.DracoChargeDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoLeapDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoTailSlamDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoTailSweepDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoStarFanDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoStarFanDefinition_rows) if (!StarBoltDefinition_ids.count(row.projectile)) return false;
    for (const auto &row:data.DracoMeteorDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoMeteorDefinition_rows) if (!EnemyRecord_ids.count(row.rock_enemy)) return false;
    for (const auto &row:data.DracoRiftsDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoPicaroWallDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoPicaroWallCandidate_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    for (const auto &row:data.DracoPicaroWallCandidate_rows) if (!EnemyRecord_ids.count(row.enemy)) return false;
    for (const auto &row:data.DracoSpiralDefinition_rows) if (!BossTechniqueDefinition_ids.count(row.technique)) return false;
    return true;
}
inline void apply_config(const RunConfig &config, godot::RunState &state) {
    state.ship_config.start_radius=config.ship_config_start_radius;
    state.ship_config.base_max_speed=config.ship_config_base_max_speed;
    state.ship_config.stick_dead_zone=config.ship_config_stick_dead_zone;
    state.ship_config.mouse_dead_zone=config.ship_config_mouse_dead_zone;
    state.ship_config.steer_cruise=config.ship_config_steer_cruise;
    state.ship_config.glide_hold=config.ship_config_glide_hold;
    state.ship_config.glide_fade=config.ship_config_glide_fade;
    state.ship_config.cruise_floor=config.ship_config_cruise_floor;
    state.ship_config.energy_cut=config.ship_config_energy_cut;
    state.ship_config.cruise_drag=config.ship_config_cruise_drag;
    state.ship_config.overcap_decay=config.ship_config_overcap_decay;
    state.ship_config.field_radius=config.ship_config_field_radius;
    state.ship_config.boundary_push=config.ship_config_boundary_push;
    state.ship_config.ship_radius=config.ship_config_ship_radius;
    state.ship_config.crash_restitution=config.ship_config_crash_restitution;
    state.ship_config.ship_hurt_time=config.ship_config_ship_hurt_time;
    state.ship_config.max_hp=config.ship_config_max_hp;
    state.ship_config.max_speed=config.ship_config_max_speed;
    state.ship_config.turn_rate=config.ship_config_turn_rate;
    state.ship_config.acceleration=config.ship_config_acceleration;
    state.ship_config.glide_duration_mult=config.ship_config_glide_duration_mult;
    state.ship_config.invulnerability=config.ship_config_invulnerability;
    state.draw_config.min_charge=config.draw_config_min_charge;
    state.draw_config.length=config.draw_config_length;
    state.draw_config.point_step=config.draw_config_point_step;
    state.draw_config.confirm_delay=config.draw_config_confirm_delay;
    state.draw_config.run_time=config.draw_config_run_time;
    state.draw_config.time_scale=config.draw_config_time_scale;
    state.draw_config.slow_ref=config.draw_config_slow_ref;
    state.draw_config.scale_min=config.draw_config_scale_min;
    state.draw_config.boost_duration=config.draw_config_boost_duration;
    state.draw_config.carry=config.draw_config_carry;
    state.draw_config.launch_ratio=config.draw_config_launch_ratio;
    state.draw_config.glide_ratio=config.draw_config_glide_ratio;
    state.draw_config.capacity=config.draw_config_capacity;
    state.draw_config.charge_time=config.draw_config_charge_time;
    state.draw_config.length_mult=config.draw_config_length_mult;
    state.control.base_view=config.camera_base_view;
    state.control.zoom_ref_speed=config.camera_zoom_ref_speed;
    state.control.zoom_exp=config.camera_zoom_exp;
    state.control.zoom_min=config.camera_zoom_min;
    state.control.look_ahead=config.camera_look_ahead;
    state.control.world_tick_div=config.world_tick_div;
    state.frame_grid_cell=config.grid_cell;
    state.control.time_limit=config.time_limit;
    state.combat_config.base_attack=config.combat_base_attack;
    state.combat_config.atk_scale=config.combat_atk_scale;
    state.combat_config.ram_speed_ratio=config.combat_ram_speed_ratio;
    state.combat_config.crit_armor=config.combat_crit_armor;
    state.combat_config.touch_damage=config.combat_touch_damage;
    state.combat_config.contact_cooldown=config.combat_contact_cooldown;
    state.combat_config.bounce_keep=config.combat_bounce_keep;
    state.combat_config.bounce_min_speed=config.combat_bounce_min_speed;
    state.combat_config.kill_hitstop=config.combat_kill_hitstop;
    state.combat_config.kill_hitstop_cap=config.combat_kill_hitstop_cap;
    state.combat_config.kill_hitstop_regen=config.combat_kill_hitstop_regen;
    state.combat_config.hitstop_big_mult=config.combat_hitstop_big_mult;
    state.combat_config.hitstop_crit_mult=config.combat_hitstop_crit_mult;
    state.combat_config.max_enemy_radius=config.combat_max_enemy_radius;
    state.combat_config.attack_mult=config.combat_attack_mult;
    state.combat_config.crit_chance=config.combat_crit_chance;
    state.combat_config.crit_mult=config.combat_crit_mult;
    state.combat_ready=config.combat_ready;
    state.pickups_ready=config.pickups_ready;
    state.pickup_config.gem_max=config.gem_max;
    state.pickup_config.strong_gold_chance=config.strong_gold_chance;
    state.pickup_config.coin_radius=config.coin_radius;
    state.pickup_config.xp_mult=config.pickup_xp_mult;
    state.pickup_config.speed_mult=config.pickup_speed_mult;
    state.pickup_config.xp_radius=config.pickup_xp_radius;
    state.pickup_config.fixed_rewards=config.fixed_rewards;
    state.projectile_config.ready=config.projectiles_ready;
    state.projectile_config.debris_life=config.debris_life;
    state.projectile_config.debris_knock=config.debris_knock;
    state.projectile_config.trail_points=config.trail_points;
    state.pickup_config.repair_fraction=config.pickup_repair_fraction;
    state.pickup_config.pickup_life=config.pickup_life;
    state.trace_radius=config.trace_radius;
}
inline EnemyDefinition to_enemy(const EnemyRecord &row, const godot::StringName &id) {
    EnemyDefinition out; out.id=id; out.spawn_ready=true; out.scaling.ready=true;
    out.hp=row.hp;
    out.armor=row.armor;
    out.radius=row.radius;
    out.speed=row.speed;
    out.fire_interval=row.fire_interval;
    out.xp=row.xp;
    out.knockback=row.knockback;
    out.hitstop_multiplier=row.hitstop_multiplier;
    out.attack_value=row.attack_value;
    out.attack_priority=row.attack_priority;
    out.attack_weight=row.attack_weight;
    out.attack_telegraph=row.warn;
    out.attack_managed=row.attack_managed;
    out.rank=row.rank;
    out.size_var=row.size_var;
    out.color.r=row.color_r;
    out.color.g=row.color_g;
    out.color.b=row.color_b;
    out.color.a=row.color_a;
    out.scaling.radius=row.scaling_radius;
    out.scaling.hp=row.scaling_hp;
    out.scaling.armor=row.scaling_armor;
    out.scaling.hp_mult=row.scaling_hp_mult;
    out.scaling.armor_mult=row.scaling_armor_mult;
    out.scaling.character=row.scaling_character;
    out.scaling.visual=row.scaling_visual;
    out.scaling.collision=row.scaling_collision;
    out.scaling.fixed_sprite=row.fixed_sprite;
    out.xp_rewards[0]=row.reward_low;
    out.xp_rewards[1]=row.reward_mid;
    out.xp_rewards[2]=row.reward_high;
    out.gold_eligible=row.gold_eligible;
    out.visual_id=row.visual_id;
    out.sprite_scale=row.sprite_scale;
    out.sprite_angle=row.sprite_angle;
    out.turn=row.turn;
    out.reward_scattered=row.reward_scattered;
    out.reward_burst=row.reward_burst;
    out.gate_arc=row.gate_arc;
    out.kind=static_cast<EnemyDefinition::Kind>(row.kind);
    return out;
}
inline constexpr uint32_t FORMAT_VERSION=1, ABI_VERSION=1, SECTION_COUNT=221;
}
