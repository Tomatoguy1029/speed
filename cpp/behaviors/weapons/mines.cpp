#include "mines.h"
#include "../../output/event_builder.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attacks/zone.h"
#include "../../state/loadout_state.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
namespace speed {
void MinesBehavior::end(RunRuntime &run) {
    auto &m=run.state.loadout->mines;if (!m.ready) return;
    auto direction=run.state.ship.heading;const auto &draw=run.state.draw;
    if (draw.path.size()>=2) {const auto segment=std::min(draw.segment,draw.path.size()-2);direction=(draw.path[segment+1]-draw.path[segment]).normalized();}
    const double heading=direction.angle(),damage=CombatResolver::attack_power(run)*EquipmentSystem::weapon_damage_factor(run,m.definition)*m.damage;
    for (uint32_t i=0;i<m.count;++i) {
        const double angle=heading+run.state.control.rng.randf_range(-m.spread,m.spread)*godot::Math::PI/180.0;
        const auto target=run.state.ship.pos+godot::Vector2::from_angle(angle)*run.state.control.rng.randf_range(m.range_min,m.range_max);
        m.items.push_back({run.state.ship.pos,run.state.ship.pos,target,++m.serial,0,m.life*(1+m.duration_increment*double(run.state.loadout->post_duration_stacks)),damage,m.radius*run.state.loadout->effects.area,false});
    }
    if (m.count>0) EventBuilder::audio(run,"weapon.mine.launch",run.state.ship.pos);
    if (m.items.size()>m.maximum) m.items.erase(m.items.begin(),m.items.begin()+(m.items.size()-m.maximum));
}
void MinesBehavior::step(RunRuntime &run,double dt) {
    auto &m=run.state.loadout->mines;if (!m.ready || dt<=0) return;
    for (auto &v:m.visuals) v.age+=dt;
    m.visuals.erase(std::remove_if(m.visuals.begin(),m.visuals.end(),[&](const auto &v){return v.age>=m.visual_life;}),m.visuals.end());
    std::vector<size_t> queue;
    const double trigger=m.trigger*run.state.loadout->effects.area;
    for (size_t i=0;i<m.items.size();++i) {
        auto &item=m.items[i];item.life-=dt;item.age+=dt;if (item.age>=0.14 && item.age-dt<0.14 && item.life>0) EventBuilder::audio(run,"weapon.mine.arm",item.to);item.pos=item.from.lerp(item.to,1-std::pow(1-std::min(1.0,item.age/0.14),3));
        if (item.life<=0 || item.age<0.14) continue;
        const double reach=trigger+std::max(run.state.combat_config.max_enemy_radius,run.state.grid.max_radius);
        const auto rows=CollisionQuery::enemy_rows(run.state,item.pos-godot::Vector2(reach,reach),item.pos+godot::Vector2(reach,reach));
        for (auto row:rows) {const auto &enemy=run.state.enemies[row];if (enemy.alive && !enemy.dead && enemy.pos.distance_squared_to(item.pos)<=(trigger+enemy.radius)*(trigger+enemy.radius)) {item.detonate=true;queue.push_back(i);break;}}
    }
    size_t cursor=0;
    while (cursor<queue.size()) {
        const auto index=queue[cursor++];if (m.items[index].life<=0) continue;
        m.items[index].life=0;const auto item=m.items[index];
        if (ZoneSystem::explode(run,item.pos,item.radius,item.damage,Cause::Mine,300*(1+m.knockback_increment*double(run.state.loadout->post_knockback_stacks)),0.6)) m.visuals.push_back({item.pos,item.radius,0,m.next_visual++});
        if (m.chain) for (size_t k=0;k<m.items.size();++k) {auto &other=m.items[k];if (other.life>0 && other.age>=0.14 && !other.detonate && other.pos.distance_squared_to(item.pos)<=item.radius*item.radius) {other.detonate=true;queue.push_back(k);EventBuilder::audio(run,"weapon.mine.chain",other.pos);}}
    }
    m.items.erase(std::remove_if(m.items.begin(),m.items.end(),[](const auto &v){return v.life<=0;}),m.items.end());
}
}
