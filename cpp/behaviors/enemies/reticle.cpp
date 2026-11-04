#include "reticle.h"
#include "sniper.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
EnemyHandle telescope(const RunRuntime &r,godot::Vector2 at) {
    const auto &s=r.state;EnemyHandle found;double best=INFINITY;
    for (size_t group=0;group<s.behavior_kinds.size();++group) if (s.behavior_kinds[group]==EnemyDefinition::Kind::Sniper) for (auto row:s.behavior_rows[group]) {
        const auto &e=s.enemies[row];if (e.dead) continue;const double distance=at.distance_squared_to(e.pos);if (distance<best) {best=distance;found=s.enemy_handles.at(uint32_t(row));}
    }return found;
}
EnemyHandle blocker(const RunRuntime &r,EnemyHandle tel,double small) {
    const auto &s=r.state;const auto &e=s.enemies[tel.slot];const auto lens=SniperBehavior::lens(e),ship=s.ship_pos,segment=ship-lens;
    const double length=lens.distance_to(ship);if (length>r.content->snipers[r.content->definitions[e.definition].sniper_definition-1].band_len) return {};
    const auto center=(lens+ship)*0.5;const double search=length*0.5+small;EnemyHandle best;double distance=INFINITY;
    for (uint32_t row=0;row<s.enemies.size();++row) {
        const auto &rock=s.enemies[row];if (!rock.alive || rock.dead || !s.field.rock_handles.contains(rock.rock) || rock.radius>small || rock.pos.distance_squared_to(center)>(search+rock.radius)*(search+rock.radius)) continue;
        const float t=segment.length_squared()>0?std::clamp(float((rock.pos-lens).dot(segment)/segment.length_squared()),0.0f,1.0f):0;
        if ((lens+segment*t).distance_to(rock.pos)>rock.radius+s.ship_config.ship_radius) continue;
        const double d=lens.distance_squared_to(rock.pos);if (d<distance) {distance=d;best=s.enemy_handles.at(row);}
    }return best;
}
}
void ReticleBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->reticles[d.reticle_definition-1];auto &state=std::get<ReticleState>(e.behavior_state);
    const auto self=s.enemy_handles.at(row);const auto tel=telescope(r,e.pos);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (!s.enemy_handles.contains(tel)) {
        budget.cancel_wait(owner,e.id);e.mode=EnemyMode::Dash;state.rock={};const auto away=(e.pos-s.ship_pos).normalized();EnemyMotion::steer(e,e.pos+away*400.0,p.retreat_speed,p.accel,dt,tracking);EnemyMotion::turn(e,away.angle(),d.turn,dt,tracking);
        const auto relative=e.pos-s.view_center;if ((std::abs(relative.x)>s.view_half.x+p.exit_margin || std::abs(relative.y)>s.view_half.y+p.exit_margin) && relative.dot(e.vel)>0) EnemySystem::mark_dead(r,self);return;
    }
    if (e.mode==EnemyMode::Dash) e.mode=EnemyMode::Move;
    const auto &support=s.enemies[tel.slot];const auto forward=godot::Vector2::from_angle(support.facing);const auto goal=support.pos+godot::Vector2(-forward.y,forward.x)*(e.id%2?1.0:-1.0)*p.follow_gap-forward*30.0;
    EnemyMotion::steer(e,goal,e.speed,p.accel,dt,tracking);const bool near=e.pos.distance_to(support.pos)<=p.follow_reach;e.fire_t-=dt;
    if (e.mode==EnemyMode::Windup) {
        if (!near || !s.enemy_handles.contains(state.rock) || s.enemies[state.rock.slot].dead) {e.mode=EnemyMode::Move;state.rock={};e.charge=0;return;}
        const auto rock=s.enemies[state.rock.slot];EnemyMotion::turn(e,(rock.pos-e.pos).angle(),d.turn*3.0,dt,tracking);e.timer-=dt;e.charge=1.0-std::max(0.0,e.timer)/p.aim_time;
        if (e.timer<=0) {
            const auto from=e.pos+godot::Vector2::from_angle(e.facing)*e.radius;godot::Dictionary beam;beam["from"]=from;beam["to"]=rock.pos;beam["width"]=10.0;beam["life"]=0.25;beam["color"]=d.color.lightened(0.3);beam["visual_key"]="enemy/reticle";FrameBuilder::append(r,"beam",beam);
            godot::Dictionary effect;effect["pos"]=rock.pos;effect["r"]=rock.radius;effect["meteor_index"]=int64_t(rock.rock.slot);effect["facing"]=rock.facing;effect["dir"]=(rock.pos-from).normalized();effect["color"]=godot::Color::html("a08a78");FrameBuilder::append(r,"rock_break",effect);
            EnemySystem::mark_dead(r,state.rock);e.mode=EnemyMode::Move;state.rock={};e.charge=0;e.fire_t=p.break_interval;
        }return;
    }
    EnemyMotion::turn(e,near?support.facing:double((support.pos-e.pos).angle()),d.turn,dt,tracking);
    if (near && e.fire_t<=0) {
        const auto rock=blocker(r,tel,p.small_r);
        if (s.enemy_handles.contains(rock)) {
            if (!e.attack_managed || (budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) || budget.request({owner,{AttackCategory::Beam},self,p.aim_time+0.25,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {state.rock=rock;state.rock_id=s.enemy_handles.entity_id(rock);e.mode=EnemyMode::Windup;e.timer=p.aim_time;}
        } else budget.cancel_wait(owner,e.id);
    } else budget.cancel_wait(owner,e.id);
}
}
