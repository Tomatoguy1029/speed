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
    if (out.kind > 7) return false;
    if (!input.read_f64(out.turn)) return false;
    if (out.turn < 0) return false;
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
    if (out.kind > 0) return false;
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
};
inline bool read(BinaryReader &input, PopulationDefinition &out) {
    if (!input.read_u32(out.id)) return false;
    if (out.id < 1) return false;
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
    if (out.role > 13) return false;
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
    std::vector<BudgetPhase> BudgetPhase_rows;
    std::vector<ProgressionDefinition> ProgressionDefinition_rows;
    std::vector<LoadoutAsset> LoadoutAsset_rows;
    std::vector<HoundDefinition> HoundDefinition_rows;
    std::vector<ShieldDefinition> ShieldDefinition_rows;
    std::vector<GunnerDefinition> GunnerDefinition_rows;
    std::vector<FieldBodyDefinition> FieldBodyDefinition_rows;
    std::vector<MoonDefinition> MoonDefinition_rows;
    std::vector<RockFieldDefinition> RockFieldDefinition_rows;
};
inline bool read_section(uint32_t kind, uint32_t version, uint32_t count, BinaryReader &input, ContentRecords &out) {
    switch(kind) {
    case 1: {
        if (version != 6) return false;
        if (count > input.remaining()/648) return false;
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
        if (version != 7) return false;
        if (count > input.remaining()/236) return false;
        for (uint32_t i=0; i<count; ++i) { EnemyRecord row; if (!read(input,row)) return false; out.EnemyRecord_rows.push_back(std::move(row)); }
        return input.remaining()==0;
    }
    case 5: {
        if (version != 3) return false;
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
        if (version != 1) return false;
        if (count) return false;
        if (count > input.remaining()/4) return false;
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
        if (version != 9) return false;
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
    case 16: {
        if (version != 1) return false;
        if (count > input.remaining()/20) return false;
        for (uint32_t i=0; i<count; ++i) { BudgetPhase row; if (!read(input,row)) return false; out.BudgetPhase_rows.push_back(std::move(row)); }
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
    std::unordered_set<uint32_t> BudgetPhase_ids;
    for (const auto &row:data.BudgetPhase_rows) if (!BudgetPhase_ids.insert(row.id).second) return false;
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
    std::unordered_set<uint32_t> FieldBodyDefinition_ids;
    for (const auto &row:data.FieldBodyDefinition_rows) if (!FieldBodyDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> MoonDefinition_ids;
    for (const auto &row:data.MoonDefinition_rows) if (!MoonDefinition_ids.insert(row.id).second) return false;
    std::unordered_set<uint32_t> RockFieldDefinition_ids;
    for (const auto &row:data.RockFieldDefinition_rows) if (!RockFieldDefinition_ids.insert(row.id).second) return false;
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
    for (const auto &row:data.LoadoutAsset_rows) if (!LoadoutDefinition_ids.count(row.equipment)) return false;
    for (const auto &row:data.LoadoutAsset_rows) if (!ResourceKey_ids.count(row.asset)) return false;
    for (const auto &row:data.HoundDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.ShieldDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
    for (const auto &row:data.ShieldDefinition_rows) if (!HostileDefinition_ids.count(row.reflected)) return false;
    for (const auto &row:data.GunnerDefinition_rows) if (!EnemyRecord_ids.count(row.id)) return false;
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
    out.kind=static_cast<EnemyDefinition::Kind>(row.kind);
    return out;
}
inline constexpr uint32_t FORMAT_VERSION=1, ABI_VERSION=1, SECTION_COUNT=28;
}
