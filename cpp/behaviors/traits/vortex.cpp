#include "vortex.h"
#include "../../systems/fuel.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/combat_resolver.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include "../heroes/gemini.h"
#include <algorithm>
namespace speed {
void VortexBehavior::end(RunRuntime &run) {
    auto &v=run.state.loadout->vortex;if (!v.ready) return;
    const double duration=v.charge+v.hold+v.collapse;
    VortexInstance instance;instance.id=++v.serial;instance.pos=run.state.ship.pos;instance.radius=v.radius*run.state.loadout->effects.area;instance.damage=CombatResolver::attack_power(run)*v.damage;instance.duration=duration;v.items.push_back(instance);
    VortexVisual visual;visual.id=instance.id;visual.pos=instance.pos;visual.life=duration+0.38;v.visuals.push_back(visual);
    godot::Dictionary event;event["pos"]=instance.pos;event["life"]=duration;FrameBuilder::append(run,"end_hole",event);
}
void VortexBehavior::step(RunRuntime &run,double dt) {
    auto &v=run.state.loadout->vortex;if (!v.ready) return;
    for (auto &visual:v.visuals) visual.age+=dt;
    v.visuals.erase(std::remove_if(v.visuals.begin(),v.visuals.end(),[](const auto &visual){return visual.age>=visual.life;}),v.visuals.end());
    // 穴は、あけた機（機体か、ふたご座の影）に付いて動く
    godot::Vector2 twin_pos=run.state.ship.pos,twin_heading,twin_velocity;GeminiBehavior::motion(run,twin_pos,twin_heading,twin_velocity);
    for (auto &instance:v.items) {
        instance.pos=instance.twin?twin_pos:run.state.ship.pos;instance.age+=dt;
        if (instance.age>=v.charge && instance.age<instance.duration) {
            const double reach=instance.radius+std::max(run.state.combat_config.max_enemy_radius,run.state.grid.max_radius);
            const auto rows=CollisionQuery::enemy_rows(run.state,instance.pos-godot::Vector2(reach,reach),instance.pos+godot::Vector2(reach,reach));
            std::vector<EnemyHandle> targets;for (auto row:rows) targets.push_back(run.state.enemy_handles.at(uint32_t(row)));
            for (auto target:targets) {
                if (!run.state.enemy_handles.contains(target)) continue;
                const auto enemy=run.state.enemies[target.slot];
                if (!enemy.alive || enemy.dead || instance.hits.count(enemy.id) || enemy.pos.distance_squared_to(instance.pos)>(instance.radius+enemy.radius)*(instance.radius+enemy.radius)) continue;
                instance.hits.insert(enemy.id);const bool lethal=!enemy.is_boss && enemy.hp<=instance.damage;
                if (lethal) run.state.enemies[target.slot].hull_scattered=true;
                DamageRequest request;request.struck=target;request.amount=instance.damage;request.cause=Cause::Vortex;request.knock=0;
                CombatResolver::damage_enemy(run,request);EventBuilder::flush_combat(run);
                const bool remains=run.state.enemy_handles.contains(target);
                if (lethal && remains && run.state.enemies[target.slot].dead) {
                    ++instance.kills;VortexVisual visual;visual.id=++v.serial;visual.kind=1;visual.pos=enemy.pos;visual.radius=enemy.radius;visual.color=run.content->definitions[enemy.definition].color;visual.facing=enemy.facing;visual.definition=uint32_t(enemy.definition+1);visual.life=0.6;visual.twin=instance.twin;v.visuals.push_back(visual);
                    godot::Dictionary event;event["pos"]=visual.pos;event["radius"]=visual.radius;event["enemy_type"]=run.content->definitions[enemy.definition].id;event["color"]=visual.color;event["facing"]=visual.facing;FrameBuilder::append(run,"hole_capture",event);
                } else if (remains) run.state.enemies[target.slot].hull_scattered=enemy.hull_scattered;
            }
        }
        if (instance.age>=instance.duration) {
            const double amount=run.state.draw_config.fuel_hole_ratio*std::min(1.0,double(instance.kills)/std::max(1.0,double(v.kills)));
            FuelSystem::add(run,run.state.draw_config.fuel_capacity*amount,false);
            VortexVisual visual;visual.id=++v.serial;visual.kind=2;visual.pos=instance.pos;visual.amount=amount;visual.life=0.78;visual.twin=instance.twin;v.visuals.push_back(visual);
            godot::Dictionary event;event["pos"]=visual.pos;event["amount"]=amount;FrameBuilder::append(run,"hole_recover",event);
        }
    }
    v.items.erase(std::remove_if(v.items.begin(),v.items.end(),[](const auto &instance){return instance.age>=instance.duration;}),v.items.end());
}
}
