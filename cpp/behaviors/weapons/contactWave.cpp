#include "contactWave.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/collision_query.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
void ContactWaveBehavior::contact(RunRuntime &run,godot::Vector2 pos) {
    auto &w=run.state.loadout.contact_wave;if (!w.ready) return;
    ContactWaveInstance wave;wave.id=w.next_id++;wave.pos=pos;
    wave.radius=w.radius*run.state.loadout.effects.area*(1+w.area_increment*double(run.state.loadout.post_area_stacks));
    wave.damage=CombatResolver::attack_power(run)*EquipmentSystem::weapon_damage_factor(run,w.definition)*w.damage;
    w.waves.push_back(wave);godot::Dictionary event;event["pos"]=pos;event["radius"]=wave.radius;event["life"]=0.58;FrameBuilder::append(run,"space_quake",event);
}
void ContactWaveBehavior::step(RunRuntime &run,double dt) {
    auto &s=run.state;auto &w=s.loadout.contact_wave;if (!w.ready || dt<=0) return;
    for (auto &wave:w.waves) {
        wave.age+=dt;if (wave.age<0.08) continue;
        const double progress=std::min(1.0,(wave.age-0.08)/0.5),radius=wave.radius*(1-std::pow(1-progress,3));
        const godot::Vector2 pad(radius+s.grid.max_radius,radius+s.grid.max_radius);
        for (auto row:CollisionQuery::enemy_rows(s,wave.pos-pad,wave.pos+pad)) {
            const auto &e=s.enemies[row];if (e.dead || wave.done.count(e.id) || e.pos.distance_to(wave.pos)>radius+e.radius) continue;
            if (std::none_of(wave.caught.begin(),wave.caught.end(),[&](const auto &h){return h.id==e.id;})) wave.caught.push_back({s.enemy_handles.at(uint32_t(row)),e.id,0});
        }
        for (auto &held:wave.caught) {
            if (!s.enemy_handles.contains(held.target) || s.enemies[held.target.slot].dead) {held.id=0;continue;}
            held.age+=dt;auto &e=s.enemies[held.target.slot];const auto direction=(e.pos-wave.pos).normalized();const auto &def=run.content->definitions[e.definition];
            const double scale=e.is_boss || (s.enemy_handles.contains(e.parent) && s.enemies[e.parent.slot].is_boss)?0:def.knockback;
            if (scale>0) e.pos+=direction*150.0*1.82*run.content->config.character_scale*dt*scale;
            if (held.age>=0.16 || progress>=1) {
                wave.done.insert(held.id);held.id=0;DamageRequest request;request.struck=held.target;request.amount=wave.damage;request.cause=Cause::ContactWave;
                request.direction=direction;request.knock=w.knock*(1+w.knockback_increment*double(s.loadout.post_knockback_stacks));CombatResolver::damage_enemy(run,request);
            }
        }
        wave.caught.erase(std::remove_if(wave.caught.begin(),wave.caught.end(),[](const auto &h){return !h.id;}),wave.caught.end());
    }
    w.waves.erase(std::remove_if(w.waves.begin(),w.waves.end(),[](const auto &wave){return wave.age>=0.58;}),w.waves.end());EventBuilder::flush_combat(run);
}
}
