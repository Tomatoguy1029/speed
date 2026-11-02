#include "run_core.h"
#include "../cpp/systems/enemy_system.h"
#include "../cpp/systems/group_system.h"
#include "../cpp/systems/tracking_policy.h"
#include "../cpp/behaviors/enemies/hound.h"
#include <algorithm>
#include <cmath>
using namespace godot;

void SpeedRunCore::spawn_hounds(size_t row, const Dictionary &options) {
    auto &enemy = runtime.state.enemies[row];
    const auto &def = runtime.content->definitions[enemy.definition];
    const int64_t pack=options.get("hound_pack",enemy.id);
    speed::GroupSystem::join(runtime.state,runtime.state.enemy_handles.at(uint32_t(row)),pack);
    if (!options.has("vel")) {
        const speed::TrackingPolicy tracking{runtime.state.draw.tracing,enemy.held,runtime.state.enemy_handles.contains(enemy.pump_owner)};
        enemy.vel=tracking.velocity(enemy.vel,enemy.facing,(runtime.state.ship_pos-enemy.pos).normalized()*enemy.speed);
        if (!tracking.locked()) enemy.facing=enemy.vel.angle();
    }
    if (options.has("hound_pack")) return;
    // 子の追加で格納配列が伸びるため、親の値は先に取り出す。
    const Enemy parent = enemy;
    const Vector2 direction = Vector2::from_angle(parent.facing), side = direction.orthogonal();
    const double gap = std::max(0.0, def.pack.gap);
    for (int64_t k = 1; k < def.pack.count; ++k) {
        const Vector2 at = parent.pos - direction * gap * double((k + 1) / 2) + side * gap * (k % 2 ? 0.5 : -0.5);
        Dictionary child = options.duplicate(); child["spawn_origin"]=int64_t(parent.origin);child["hound_pack"] = pack; child["facing"] = parent.facing;
        child["attack_group"] = parent.attack_group; child["attack_value"] = parent.attack_value; child["attack_priority"] = parent.attack_priority;
        spawn_enemy(def.id, at, child);
    }
}
bool SpeedRunCore::running_hound(size_t row) const {return speed::HoundBehavior::running(runtime.state,uint32_t(row));}
Vector2 SpeedRunCore::hound_velocity(size_t row) const {return speed::HoundBehavior::pack_velocity(runtime,uint32_t(row));}
void SpeedRunCore::prepare_hounds(const std::vector<size_t> &rows) {speed::HoundBehavior::prepare(runtime,rows);}
void SpeedRunCore::remove_hound(size_t row) {speed::EnemySystem::leave_hound(runtime.state,row);}
bool SpeedRunCore::follow_hound(int64_t id, Vector2 goal, double until, double scale) {
    if (!runtime.state.started || runtime.state.closed || !goal.is_finite() || !std::isfinite(until) || !std::isfinite(scale) || scale < 0) return false;
    const auto found = runtime.state.rows_by_id.find(id); if (found == runtime.state.rows_by_id.end()) return false;
    return speed::GroupSystem::follow(runtime.state,runtime.state.enemy_handles.at(uint32_t(found->second)),goal,until,scale);
}
Dictionary SpeedRunCore::hound_snapshot() const {
    Array packs, follows;
    for (const auto &entry:runtime.state.groups.groups) {
        Dictionary pack;Array members;
        for (const auto &member:entry.value.members) members.append(member.key);
        pack["id"]=entry.key;pack["members"]=members;packs.append(pack);
    }
    for (const auto &entry:runtime.state.groups.groups) for (const auto &member:entry.value.members) {
        const auto &o=member.value.order;if (!o.follow) continue;
        Dictionary f;f["id"]=member.key;f["goal"]=o.follow_goal;f["until"]=o.follow_until;f["scale"]=o.follow_scale;follows.append(f);
    }
    std::vector<Dictionary> ordered;for (int64_t i=0;i<follows.size();++i) ordered.push_back(follows[i]);
    std::sort(ordered.begin(),ordered.end(),[](const auto &a,const auto &b){return int64_t(a["id"])<int64_t(b["id"]);});
    follows.clear();for (const auto &f:ordered) follows.append(f);
    Dictionary out; out["packs"] = packs; out["follows"] = follows; return out;
}
