#include "field.h"
#include "enemy_system.h"
#include "attack_system.h"
#include "attacks/friend_hull.h"
#include "../api/run_core.h"
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/math.hpp>
namespace speed {
namespace {
bool near(const RunRuntime &run,godot::Vector2 point,double extra) {
    const auto delta=(point-run.state.view_center).abs();const double radius=point.length();
    const auto &config=run.content->rock_fields.front();
    return delta.x<run.state.view_half.x+extra && delta.y<run.state.view_half.y+extra &&
        radius>config.planet_radius+100.0 && radius<run.state.ship_config.field_radius+100.0;
}
void place(RunRuntime &run,godot::Vector2 position,RockKind kind,godot::Vector2 velocity) {
    const double radius=position.length();
    if (radius<run.content->rock_fields.front().planet_radius+200.0 || radius>run.state.ship_config.field_radius-100.0) return;
    auto &rng=run.state.control.rng;FieldRock rock;rock.kind=kind;rock.position=position;rock.velocity=velocity;
    rock.size=rng.randf_range(24.0,65.0);rock.facing=rng.randf()*godot::Math::TAU;rock.spin=rng.randf_range(-0.5,0.5);
    if (kind==RockKind::Iron) rock.size=rng.randf_range(30.0,50.0);
    else if (kind==RockKind::Saw) {rock.size=30.0;rock.spin=8.0;}
    FieldSystem::add_rock(run,rock);
}
}
RockHandle FieldSystem::add_rock(RunRuntime &run,FieldRock rock) {
    auto &field=run.state.field;if (field.rocks.size()>=UINT32_MAX) return {};
    const auto slot=uint32_t(field.rocks.size());const auto handle=field.rock_handles.attach(slot,int64_t(slot)+1);
    field.rocks.push_back(rock);field.stream_t=0;return handle;
}
void FieldSystem::initialize_rocks(RunRuntime &run) {
    if (run.content->rock_fields.empty()) return;
    const auto &config=run.content->rock_fields.front();auto &rng=run.state.control.rng;
    const double radius=run.state.ship_config.field_radius;
    for (int64_t i=0;i<std::round(config.meteor_count*0.45);++i) {
        const double angle=rng.randf()*godot::Math::TAU,distance=rng.randf_range(1100.0,radius-650.0);
        const auto center=godot::Vector2::from_angle(angle)*distance;
        for (int j=0;j<8;++j) {
            const double a=rng.randf()*godot::Math::TAU,d=std::sqrt(rng.randf())*380.0;
            place(run,center+godot::Vector2::from_angle(a)*d,RockKind::Belt,{});
        }
    }
    for (int64_t i=0;i<std::round(config.meteor_count*2.5);++i) {
        const double distance=std::sqrt(rng.randf_range(800.0*800.0,std::pow(radius-300.0,2.0)));
        const double heading=rng.randf()*godot::Math::TAU,angle=rng.randf()*godot::Math::TAU;
        const double speed=rng.randf_range(15.0,35.0);
        place(run,godot::Vector2::from_angle(angle)*distance,RockKind::Drift,godot::Vector2::from_angle(heading)*speed);
    }
    for (uint32_t i=0;i<config.iron_count;++i) {
        const double angle=rng.randf()*godot::Math::TAU,distance=rng.randf_range(1100.0,radius-650.0);
        const auto center=godot::Vector2::from_angle(angle)*distance;const auto count=rng.randi_range(3,5).value();
        for (int64_t j=0;j<count;++j) {
            const double a=rng.randf()*godot::Math::TAU,d=std::sqrt(rng.randf())*240.0;
            place(run,center+godot::Vector2::from_angle(a)*d,RockKind::Iron,{});
        }
    }
    for (uint32_t i=0;i<config.saw_count;++i) {
        const double distance=std::sqrt(rng.randf_range(900.0*900.0,std::pow(radius-400.0,2.0))),angle=rng.randf()*godot::Math::TAU;
        place(run,godot::Vector2::from_angle(angle)*distance,RockKind::Saw,{});
    }
}
godot::Vector2 FieldSystem::rock_at(const RunRuntime &run,const FieldRock &rock) {
    const double now=run.state.world_time;
    if (rock.kind==RockKind::Comet) return rock.position+rock.velocity*(now-rock.born);
    auto point=rock.position+rock.velocity*now;const double radius=run.state.ship_config.field_radius;
    point.x=godot::Math::fposmod(point.x+radius,radius*2.0)-radius;
    point.y=godot::Math::fposmod(point.y+radius,radius*2.0)-radius;return point;
}
void FieldSystem::stream_rocks(RunRuntime &run,double dt) {
    if (dt<=0 || run.content->rock_fields.empty()) return;
    auto &state=run.state;auto &field=state.field;const auto &config=run.content->rock_fields.front();
    for (auto &rock:field.rocks) {
        if (!rock.proxy.generation) continue;
        if (!state.enemy_handles.contains(rock.proxy) || state.enemies[rock.proxy.slot].dead) {
            if (!state.enemy_handles.contains(rock.proxy) || !state.enemies[rock.proxy.slot].hull_scattered) rock.destroyed=true;
            rock.proxy={};continue;
        }
        auto &enemy=state.enemies[rock.proxy.slot];enemy.pos=rock_at(run,rock);enemy.vel=rock.velocity;enemy.facing=rock.facing+rock.spin*state.world_time;
        if (rock.kind==RockKind::Comet && state.world_time>=rock.gone) rock.destroyed=true;
        if (rock.destroyed || (!rock.manual && !near(run,enemy.pos,650.0))) {EnemySystem::retire(run,rock.proxy,RetireReason::Outside);rock.proxy={};}
    }
    field.stream_t-=dt;if (field.stream_t>0) return;field.stream_t=0.2;
    for (uint32_t i=0;i<field.rocks.size();++i) {
        auto &rock=field.rocks[i];if (rock.destroyed || rock.proxy.generation) continue;
        if (rock.kind==RockKind::Comet && state.world_time>=rock.gone) {rock.destroyed=true;continue;}
        const auto at=rock_at(run,rock);if (!rock.manual && !near(run,at,300.0)) continue;
        const uint32_t definition=rock.kind==RockKind::Iron?config.iron:rock.kind==RockKind::Saw?config.saw:config.meteor;
        EnemySpawn params;params.position=at;params.velocity=rock.velocity;params.facing=rock.facing;params.rock=field.rock_handles.at(i);
        params.size=(rock.kind==RockKind::Belt || rock.kind==RockKind::Drift)?(i%2==0?60.0:40.0):rock.size;
        const auto id=EnemySystem::spawn_base(run,definition-1,params);
        if (id>0) rock.proxy=state.enemy_handles.at(uint32_t(state.rows_by_id.at(id)));
    }
}
bool FieldSystem::contact_rock(godot::SpeedRunCore &core,uint32_t row,godot::Vector2 direction,godot::Vector2 from,double speed) {
    auto &run=core.runtime;auto &state=run.state;auto &enemy=state.enemies[row];
    if (run.content->definitions[enemy.definition].kind!=EnemyDefinition::Kind::Saw || run.content->rock_fields.empty()) return false;
    const auto &config=run.content->rock_fields.front();const auto u=direction.is_zero_approx()?(enemy.pos-from).normalized():direction;
    FriendHullParams shot;shot.saw=true;shot.position=enemy.pos;shot.velocity=u*std::max(config.saw_speed,speed);shot.radius=enemy.radius;
    shot.damage=state.combat_config.base_attack*state.combat_config.attack_mult*state.combat_config.atk_scale*config.saw_power;shot.life=config.saw_life;
    FriendHullSystem::emit(run,shot);
    godot::Dictionary event;event["pos"]=enemy.pos;event["normal"]=-u;event["enemy_pos"]=enemy.pos;event["r"]=enemy.radius;core.emit_event("block_impact",event);
    EnemySystem::retire(core.runtime,state.enemy_handles.at(row),RetireReason::Development);return true;
}
uint32_t FieldSystem::rock_visual(const RunRuntime &run,uint32_t row) {
    const auto &enemy=run.state.enemies[row];const auto &definition=run.content->definitions[enemy.definition];
    if (definition.kind!=EnemyDefinition::Kind::Meteor || run.content->rock_fields.empty()) return definition.visual_id;
    const auto &config=run.content->rock_fields.front();
    const int variant=run.state.field.rock_handles.contains(enemy.rock)?enemy.rock.slot%2:1;
    const int damage=std::clamp(int((1.0-enemy.hp/enemy.max_hp)*3.0),0,2);
    const uint32_t ids[]={config.meteor_visual_0,config.meteor_visual_1,config.meteor_visual_2,config.meteor_visual_3,config.meteor_visual_4,config.meteor_visual_5};
    return ids[variant*3+damage];
}
double FieldSystem::rock_sprite_radius(const RunRuntime &run,uint32_t row) {
    const auto &enemy=run.state.enemies[row];if (run.content->definitions[enemy.definition].kind!=EnemyDefinition::Kind::Meteor || run.content->rock_fields.empty()) return enemy.radius;
    const auto &config=run.content->rock_fields.front();return run.state.field.rock_handles.contains(enemy.rock) && enemy.rock.slot%2==0?config.meteor_radius_0:config.meteor_radius_1;
}
}
