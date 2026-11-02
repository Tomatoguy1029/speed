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
    if (out.kind > 30) return false;
    if (!input.read_f64(out.turn)) return false;
    if (out.turn < 0) return false;
    if (!input.read_bool(out.reward_scattered)) return false;
    if (!input.read_bool(out.reward_burst)) return false;
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
};
inline bool read(BinaryReader &input, HeroDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
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
};
inline bool read(BinaryReader &input, FormationDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
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
    if (out.role > 15) return false;
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
    std::vector<ProgressionDefinition> ProgressionDefinition_rows;
    std::vector<LoadoutAsset> LoadoutAsset_rows;
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
        if (version != 8) return false;
        if (count > input.remaining()/238) return false;
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
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
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
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
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
        if (version != 11) return false;
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
    std::unordered_set<uint32_t> ProgressionDefinition_ids;
    for (const auto &row:data.ProgressionDefinition_rows) if (!ProgressionDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> LoadoutAsset_ids;
    for (const auto &row:data.LoadoutAsset_rows) if (!LoadoutAsset_ids.insert(row.id).second) return false;
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
    for (const auto &row:data.LoadoutAsset_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.LoadoutAsset_rows) if (!ResourceKey_ids.count(row.asset)) return false;
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
    out.kind=static_cast<EnemyDefinition::Kind>(row.kind);
    return out;
}
inline constexpr uint32_t FORMAT_VERSION=1, ABI_VERSION=1, SECTION_COUNT=98;
}
