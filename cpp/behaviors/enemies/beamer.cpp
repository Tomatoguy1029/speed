#include "beamer.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/beam.h"
#include "../../output/frame_builder.h"
#include "../../content/content_bundle.h"
#include <algorithm>
namespace speed {
namespace {
void sound(RunRuntime &run,const char *type,uint32_t row,bool include_row=false,double time=0) {
    godot::Dictionary event;event["id"]=run.state.enemies[row].id;if (include_row) {event["row"]=int64_t(row);event["time"]=time;}
    FrameBuilder::append(run,type,event);
}
}
void BeamerBehavior::step(RunRuntime &run,uint32_t row,double dt) {
    using Mode=godot::RunState::EnemyMode;
    auto &state=run.state;auto &enemy=state.enemies[row];const auto &definition=run.content->definitions[enemy.definition];
    const auto &beam=run.content->beamers[definition.beamer_definition-1];const auto handle=state.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(state,enemy.id,enemy.attack_group);AttackBudgetSystem budget(run);
    if (enemy.attack_managed && !(budget.owns(owner,enemy.id) && EnemySystem::attack_active(state,handle)) && EnemySystem::attack_due(run,handle,dt)) {
        const BudgetRequest request{owner,{AttackCategory::Beam},handle,beam.admission_duration,enemy.attack_priority,state.world.attack_formation_mode?enemy.attack_value:definition.attack_weight};
        if (!budget.request(request)) {enemy.charge=0;EnemyMotion::keep_distance(run,row,beam.keep,beam.accel,dt);return;}
    }
    if (enemy.mode==Mode::Move) EnemyMotion::keep_distance(run,row,beam.keep,beam.accel,dt);
    else enemy.vel*=std::max(0.0,1.0-8.0*dt);
    if (enemy.mode==Mode::Move) {
        enemy.fire_t=remaining_time(enemy.fire_t,dt);if (enemy.fire_t>0) return;
        const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
        const double angle=tracking.angle(enemy.facing,(state.enemy_aim-enemy.pos).angle());
        enemy.facing=angle;enemy.mode=Mode::Windup;enemy.timer=beam.telegraph+beam.beam_time;
        sound(run,"enemy_laser_charge",row,true,beam.telegraph);
        BeamParams params;params.owner=handle;params.style=BeamStyle::Guide;
        params.length=beam.beam_length;params.half_width=beam.half_width;params.delay=beam.telegraph;params.active=beam.beam_time;
        params.damage=beam.damage;params.color=definition.color.lightened(0.3);
        if (enemy.attack_managed) params.budget.value=budget.token(owner);
        const int count=beam.cross?4:1;
        for (int i=0;i<count;++i) {
            params.angle=angle+(beam.cross?godot::Math::PI/4.0+i*godot::Math::PI/2.0:0.0);
            params.position=beam.cross?enemy.pos:enemy.pos+godot::Vector2::from_angle(angle)*enemy.radius;
            BeamSystem::emit(run,params);
        }
        return;
    }
    const double before=enemy.timer;enemy.timer=remaining_time(enemy.timer,dt);
    if (before>beam.beam_time && enemy.timer<=beam.beam_time) sound(run,"enemy_laser_fire",row);
    enemy.charge=std::clamp(1.0-(enemy.timer-beam.beam_time)/beam.telegraph,0.0,1.0);
    if (enemy.timer<=0) {enemy.mode=Mode::Move;enemy.fire_t=definition.fire_interval;enemy.charge=0;}
}
}
