#include "split.h"
#include "pursuit.h"
#include "../../output/frame_builder.h"
#include <godot_cpp/core/math.hpp>
namespace speed {
void SplitBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->splits[d.split_definition-1];
    const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);
    auto &state=std::get<SplitState>(e.behavior_state);state.bud_t+=dt;if (state.bud_t<p.bud_interval) return;state.bud_t=0;
    if (state.buds>=p.max_buds) return;
    const double angle=double(e.id)*2.39996322973+double(state.buds)*2.399963;++state.buds;const auto u=godot::Vector2::from_angle(angle);
    s.pending_enemies.push_back({p.child,e.pos+u*e.radius*1.2,u*160.0,angle,0.2,0,0,e.attack_priority,SpawnOrigin::Split,e.picaro_owner});
    godot::Dictionary event;event["pos"]=e.pos+u*e.radius;event["color"]=d.color;FrameBuilder::append(r,"bud",event);
}
void SplitBehavior::died(RunRuntime &r,const DeathContext &death) {
    const auto &d=r.content->definitions[death.corpse.definition-1];if (d.kind!=EnemyDefinition::Kind::Split) return;
    const auto &p=r.content->splits[d.split_definition-1];if (!p.death_split) return;
    const auto n=std::max<int64_t>(1,int64_t(p.death_split)+r.state.control.rng.randi_range(0,p.split_extra).value());
    const double priority=death.corpse.attack_priority;
    for (int64_t k=0;k<n;++k) {
        const double angle=death.corpse.facing+(n>2?godot::Math::PI/2+godot::Math::TAU*double(k)/double(n):(k==1?1:-1)*godot::Math::PI/2);
        const auto u=godot::Vector2::from_angle(angle);
        r.state.pending_enemies.push_back({p.child,death.corpse.pos+u*death.corpse.radius,u*p.split_speed,angle,0.35,p.split_guard,p.split_guard,priority,SpawnOrigin::Split,r.state.enemies[death.target.slot].picaro_owner});
    }
}
}
