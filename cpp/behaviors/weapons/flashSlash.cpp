#include "flashSlash.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include "../../state/loadout_state.h"
#include <algorithm>
namespace speed {
void FlashSlashBehavior::contact(RunRuntime &r,EnemyHandle target,double damage) {auto &s=r.state;auto &w=s.loadout->flash_slash;target=CombatResolver::damage_target(r,target);if (!w.ready || !s.draw.tracing || !s.enemy_handles.contains(target)) return;auto &e=s.enemies[target.slot];if (e.dead || !w.marked_ids[s.draw.dash_id].insert(e.id).second) return;
    FlashSlashMark m;m.target=target;m.id=e.id;m.dash=s.draw.dash_id;m.distance=s.loadout->boost_distance;m.damage=(damage>0?damage:CombatResolver::attack_power(r)*EquipmentSystem::weapon_damage_factor(r,w.definition))*w.multiplier;m.left=m.total=w.cuts;w.marks.push_back(m);if (!e.is_boss) e.slash_hold=true;e.flash=0.07;
    godot::Dictionary event;event["pos"]=e.pos;event["radius"]=e.radius;event["id"]=e.id;event["dash"]=m.dash;FrameBuilder::append(r,"slash_mark",event);
}
void FlashSlashBehavior::end(RunRuntime &r) {auto &s=r.state;auto &w=s.loadout->flash_slash;if (!w.ready) return;for (auto &m:w.marks) if (m.dash==s.draw.dash_id && m.time<0) {m.time=0;m.delay=w.pause+w.sweep*std::clamp(m.distance/std::max(s.loadout->boost_distance,1.0),0.0,1.0);}w.released=0;
    godot::Dictionary event;event["path"]=s.draw.path;event["count"]=w.streaks;event["sweep"]=w.sweep;event["pause"]=w.pause;FrameBuilder::append(r,"slash_release",event);
}
void FlashSlashBehavior::step(RunRuntime &r,double dt) {auto &s=r.state;auto &w=s.loadout->flash_slash;if (!w.ready || dt<=0) return;w.clock+=dt;if (w.released>=0) w.released+=dt;
    // 印の取得順を維持する。別の印が残っていても、完了した印はboolを解除する。
    for (auto &m:w.marks) {m.age+=dt;const bool same=s.enemy_handles.contains(m.target) && s.enemy_handles.entity_id(m.target)==m.id;if (!same || s.enemies[m.target.slot].dead) {m.left=0;if (same) s.enemies[m.target.slot].slash_hold=false;continue;}if (m.time<0) continue;m.time+=dt;
        while (m.left>0 && m.time>=m.delay+(m.total-m.left)*0.025) {--m.left;DamageRequest q;q.struck=m.target;q.amount=m.damage/m.total;q.cause=Cause::FlashSlash;q.weapon_id=w.definition;q.no_crit=true;q.knock=0;CombatResolver::damage_enemy(r,q);EventBuilder::flush_combat(r);
            godot::Dictionary event;event["pos"]=s.enemies[m.target.slot].pos;event["length"]=150.0;event["width"]=3.2;event["id"]=m.id;event["dash"]=m.dash;event["cut"]=m.total-m.left-1;FrameBuilder::append(r,"flash_slash",event);
        }if (!m.left) s.enemies[m.target.slot].slash_hold=false;
    }
    for (const auto &m:w.marks) if (!m.left) {auto found=w.marked_ids.find(m.dash);if (found!=w.marked_ids.end()) {found->second.erase(m.id);if (found->second.empty()) w.marked_ids.erase(found);}}
    w.marks.erase(std::remove_if(w.marks.begin(),w.marks.end(),[](const auto &m){return !m.left;}),w.marks.end());
}
void FlashSlashBehavior::dispose(RunRuntime &r) {auto &s=r.state;auto &w=s.loadout->flash_slash;for (const auto &m:w.marks) if (s.enemy_handles.contains(m.target) && s.enemy_handles.entity_id(m.target)==m.id) s.enemies[m.target.slot].slash_hold=false;w={};}
}
