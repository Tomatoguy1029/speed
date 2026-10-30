#pragma once
#include "runtime_data.h"
#include "run_state.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <unordered_map>
#include <unordered_set>
#include <deque>
#include <array>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {
// 可変状態は各ランが所有する。終了した実体は再利用しない。
class SpeedRunCore : public RefCounted, private SpeedRunState {
    GDCLASS(SpeedRunCore, RefCounted)
    bool can_avoid_strong(size_t row) const;
    void capture_avoidance();
    double avoidance_clearance(Vector2 point, size_t row, const std::vector<size_t> &candidates) const;
    void spawn_hounds(size_t row, const Dictionary &options);
    void remove_hound(size_t row);
    bool running_hound(size_t row) const;
    Vector2 hound_velocity(size_t row) const;
    void prepare_hounds(const std::vector<size_t> &rows);
    void sync_attack_budget();
    bool attack_guard_active() const;
    double used_attack_cost() const;
    StringName next_attack_owner() const;
    void reset_enemy_bounds();
    std::vector<size_t> query_enemy_rows(Vector2 lo, Vector2 hi) const;
    void refresh_progression_stats();
    void apply_stat_values(const Dictionary &stats);
    void publish_cards();
    Array roll_cards(bool initial);
    bool apply_card(int64_t index);
    void level_bonus();
    void begin_draw(bool press, Vector2 pen, int64_t clock_msec);
    void extend_draw(Vector2 pen, double camera_zoom);
    void commit_draw();
    void end_trace(bool completed);
    void steer_ship(double want, double dt);
    void move_ship(double dt, Vector2 accel);
    void emit_event(StringName type, Dictionary data = Dictionary());
    void kill_enemy(size_t row, bool crit, StringName cause, Vector2 direction);
    void damage_enemy(size_t row, double amount, StringName cause, bool crit, Vector2 direction, double knock = 160.0, const Vector2 *impact = nullptr);
    bool blocks_front(size_t row, Vector2 hit, Vector2 direction) const;
    void collect_pickup(StringName kind, double value = 0);
    void drop_enemy_pickups(const Enemy &enemy);
    void drop_gem(Vector2 position, double value);
    size_t add_friend(Friendly shot);
    void duplicate_friend(size_t source, Vector2 impact);
    void end_bite_visual(bool hit, Vector2 at);
    size_t add_hostile(Hostile shot);
    bool damage_ship(double amount, double slow, StringName cause, StringName source = StringName());
    void step_forward(double world_dt);
    bool check_run_end();
    void step_death(double real_dt);
    StringName enemy_attack_owner(const Enemy &enemy) const;
    bool admit_bite(Enemy &enemy, double dt);
    void advance_biter(size_t row, double dt, bool far);
    void update_pushed(Enemy &enemy, double dt);
    void advance_enemies(double delta);
protected:
    static void _bind_methods();
public:
    bool set_attack_budget_mode(bool enabled, bool from_stage);
    bool advance_attack_budget(double at);
    void cancel_attack_wait(StringName owner, int64_t id);
    void cancel_attack(StringName owner, int64_t id);
    bool owns_attack(StringName owner, int64_t id) const;
    int64_t attack_token(StringName owner) const;
    int64_t passive_attack(StringName owner, int64_t id);
    void track_attack_external(int64_t token, const String &key);
    void release_attack_external(int64_t token, const String &key);
    bool configure_attack_budget(const Dictionary &settings);
    bool set_attack_guard(bool active, double until);
    bool request_attack(StringName owner, const PackedStringArray &categories, int64_t id, double duration, double priority, double cost);
    Dictionary attack_budget_snapshot() const;
    bool configure_bite_zone(const Dictionary &data);
    int64_t fire_bite_zone(Vector2 at, double radius, double delay, double damage, Color color, int64_t token);
    bool step_hazards(double dt);
    Array hazards_snapshot() const;
    bool set_enemy_motion(int64_t id, const Dictionary &state);
    Array enemy_motion_snapshot() const;
    bool configure_population(const Dictionary &config);
    bool configure_clips(const Dictionary &data);
    bool step_clips();
    Array clips_snapshot() const;
    bool configure_formations(const Array &data, double base_view);
    PackedInt64Array spawn_formation(int64_t index, int64_t layout, int64_t entry, const PackedStringArray &types, double value, const Variant &priority, const Variant &managed);
    bool set_attack_formation_mode(bool enabled);
    Array enemy_attack_snapshot() const;
    bool configure_refill(const Dictionary &config);
    bool step_population(double world_dt, bool bonus);
    bool set_population_mode(bool enabled, bool bonus, bool blocked);
    Dictionary refill_snapshot() const;
    double survey_population(double target);
    Variant population_spawn_point(double extra);
    Dictionary population_snapshot() const;
    bool configure_enemy_order(const PackedStringArray &order);
    PackedInt64Array enemy_order_snapshot() const;
    bool configure_spawn_timeline(const Dictionary &data);
    Dictionary spawn_target(double at, bool bonus) const;
    bool configure_lifecycle(const Dictionary &config);
    bool set_run_guards(const Dictionary &guards);
    bool set_paused(bool paused);
    bool configure_forward(const Dictionary &parameters, int64_t level, double character_scale);
    Dictionary forward_snapshot() const;
    bool set_forward_level(int64_t level);
    int64_t spawn_hostile(const Dictionary &fields);
    bool step_hostiles(double world_dt);
    Array hostiles_snapshot() const;
    bool configure_projectiles(const Dictionary &config, const Dictionary &split);
    bool burst_debris(Vector2 position, int64_t count, double speed, double damage, Color color, int64_t source_id);
    bool fire_shot(Vector2 from, double angle, double damage, const Dictionary &options);
    bool step_projectiles(double world_dt);
    Array projectiles_snapshot() const;
    PackedFloat32Array friendly_buffer(StringName visual, double pixel, double scale, double clock) const;
    bool configure(const Dictionary &data);
    bool configure_ship(const Dictionary &config, const Dictionary &stats);
    bool step_ship(double real_dt, double world_dt, const Dictionary &input);
    Dictionary ship_snapshot() const;
    bool configure_frame(const Dictionary &config);
    bool step_frame(double real_dt, const Dictionary &input, Vector2 center, Vector2 half, double camera_zoom);
    bool configure_pickups(const Dictionary &config, const Dictionary &stats);
    Dictionary pickups_snapshot() const;
    PackedFloat32Array pickup_buffer(StringName kind, double size, Color color, Rect2 view) const;
    bool step_pickups(double world_dt);
    Array drain_collections();
    bool configure_combat(const Dictionary &config, const Dictionary &stats);
    bool collide_ship(Vector2 from, double radius);
    Dictionary combat_snapshot() const;
    Array drain_events();
    bool configure_draw(const Dictionary &config, const Dictionary &stats);
    bool handle_draw(const Dictionary &input, int64_t clock_msec, double camera_zoom);
    bool step_draw(double real_dt);
    double world_scale() const;
    Dictionary draw_snapshot() const;
    bool start(int64_t seed, int64_t first_id = 1, int64_t first_gem_seq = 0);
    bool set_motion_context(Vector2 ship, Vector2 center, Vector2 half);
    int64_t spawn_enemy(StringName type, Vector2 position, const Dictionary &options);
    bool remove_enemy(int64_t id);
    bool follow_hound(int64_t id, Vector2 goal, double until, double scale);
    Dictionary hound_snapshot() const;
    bool configure_progression(const Dictionary &data);
    bool grant_equipment(StringName kind, StringName id, int64_t levels = 1);
    bool add_xp(double amount);
    bool open_cards(bool initial = false);
    bool reroll_cards();
    bool choose_card(int64_t index, int64_t revision);
    bool resources_ready(int64_t revision, StringName id, int64_t status);
    Array drain_resource_requests();
    Dictionary progression_snapshot() const;
    bool apply_external_progression(const Dictionary &stats, double hp, bool waiting, int64_t random_state);
    int64_t random_state() const;
    int64_t progression_revision() const;
    bool avoid_strong(double dt);
    Array enemies_snapshot() const;
    bool rebuild_enemy_grid(double cell_size);
    PackedInt64Array query_enemy_ids(Vector2 lo, Vector2 hi) const;
    PackedFloat32Array enemy_buffer(StringName type, double scale, double angle_offset) const;
    bool step(double delta);
    void close();
    Dictionary inspect() const;
    Ref<SpeedRunCore> checkpoint() const;
    bool update_enemy_definition(StringName id, const Dictionary &data);
};
}
