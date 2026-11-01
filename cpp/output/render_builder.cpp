#include "render_builder.h"
#include "../runtime/run_runtime.h"
#include "../systems/motion_math.h"
#include "../systems/group_system.h"
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <map>
#include <cmath>
namespace speed {
using namespace godot;
Dictionary RenderBatchBuffer::value() {
    ids.resize(instances.size());transforms.resize(instances.size()*6);colors.resize(instances.size());flags.resize(instances.size());
    auto *t=transforms.ptrw();auto *id=ids.ptrw();auto *color=colors.ptrw();auto *flag=flags.ptrw();
    for (size_t i=0;i<instances.size();++i) {
        const auto &v=instances[i];const float c=std::cos(v.angle)*v.radius,s=std::sin(v.angle)*v.radius;
        id[i]=v.id;flag[i]=v.flags;color[i]=v.color;
        t[i*6]=c;t[i*6+1]=s;t[i*6+2]=-s;t[i*6+3]=c;t[i*6+4]=v.at.x;t[i*6+5]=v.at.y;
    }
    Dictionary out;out["visual_id"]=visual;out["layer"]=layer;out["order"]=order;out["ids"]=ids;
    out["transforms"]=transforms;out["colors"]=colors;out["flags"]=flags;
    if (biter) {Dictionary values;values["modes"]=modes;values["charges"]=charges;values["timers"]=timers;values["rests"]=rests;out["biter"]=values;}
    if (!glows.is_empty()) out["glows"]=glows;
    return out;
}
namespace {
PreviousPose interpolate(const PreviousPoseState &old,const PreviousPose &now,size_t slot,bool friendly,double alpha) {
    const auto &poses=friendly?old.friendly:old.enemies;
    if (!old.ready || slot>=poses.size() || poses[slot].id!=now.id) return now;
    const auto &before=poses[slot];return {now.id,before.position.lerp(now.position,alpha),before.angle+angle_difference(now.angle-before.angle)*alpha};
}
}
void RenderBuilder::capture_previous(RunRuntime &run) {
    auto &previous=run.state.previous_poses;const auto &state=run.state;
    previous.ship_position=state.ship.pos;previous.ship_angle=state.ship.heading.angle();previous.ready=true;
    previous.enemies.resize(state.enemies.size());
    for (size_t i=0;i<state.enemies.size();++i) {const auto &enemy=state.enemies[i];previous.enemies[i]={enemy.alive?enemy.id:0,enemy.pos,enemy.facing};}
    previous.friendly.resize(state.friends.size());
    for (size_t i=0;i<state.friends.size();++i) {const auto &shot=state.friends[i];previous.friendly[i]={shot.alive?shot.id:0,shot.pos,shot.vel.angle()};}
}
Dictionary RenderBuilder::read(const RunRuntime &run,Rect2 view,double alpha) {
    const auto &state=run.state;const auto &config=run.content->config;const auto &previous=state.previous_poses;
    auto &groups=run.render_workspace.batches;
    for (auto &group:groups) {
        auto &out=group.second;out.instances.clear();out.biter=false;
        out.modes.clear();out.charges.clear();out.timers.clear();out.rests.clear();out.glows.clear();
    }
    const auto batch=[&](uint32_t visual,int32_t layer,int32_t order)->RenderBatchBuffer & {
        auto &out=groups[visual];out.visual=visual;out.layer=layer;out.order=order;return out;
    };
    for (const auto &body:state.field.bodies) {
        const auto &definition=run.content->field_bodies[body.definition];
        if (view.grow(definition.radius).has_point(body.position)) batch(definition.visual,2,0).add(definition.id,body.position,0,definition.radius,Color(0,0,0,1));
    }
    for (size_t i=0;i<state.enemies.size();++i) {
        const auto &enemy=state.enemies[i];if (!enemy.alive || enemy.dead) continue;
        const auto &definition=run.content->definitions[enemy.definition];if (!definition.visual_id) continue;
        const auto pose=interpolate(previous,{enemy.id,enemy.pos,enemy.facing},i,false,alpha);
        const double radius=enemy.radius*definition.sprite_scale;
        if (!view.grow(radius*1.4142135623730951).has_point(pose.position)) continue;
        auto &enemy_batch=batch(definition.visual_id,8,int32_t(enemy.definition));
        if (definition.kind==EnemyDefinition::Kind::Biter) {
            enemy_batch.biter=true;enemy_batch.modes.push_back(int32_t(enemy.mode));enemy_batch.charges.push_back(enemy.charge);
            enemy_batch.timers.push_back(enemy.timer);enemy_batch.rests.push_back(definition.bite.rest);
        }
        const bool warning=definition.kind==EnemyDefinition::Kind::Hound && GroupSystem::warning(state,state.enemy_handles.at(uint32_t(i)));
        if (warning) {enemy_batch.glows.push_back(pose.position.x);enemy_batch.glows.push_back(pose.position.y);enemy_batch.glows.push_back(radius);}
        enemy_batch.add(enemy.id,pose.position,pose.angle+definition.sprite_angle,radius,
            Color(enemy.flash>0 || warning?1.0:0.0,0,0,1),enemy.flash>0 || warning?1:0);
    }
    for (size_t i=0;i<state.friends.size();++i) {
        const auto &shot=state.friends[i];if (!shot.alive) continue;
        const auto pose=interpolate(previous,{shot.id,shot.pos,shot.vel.angle()},i,true,alpha);
        const double radius=18.0*1.82*config.character_scale;
        if (!view.grow(radius).has_point(pose.position)) continue;
        batch(config.shot_visual,10,0).add(shot.id,pose.position,pose.angle,1.82*config.character_scale,Color(1,1,1,1));
    }
    const Color crystal_colors[]={Color::html("08deff"),Color::html("945cff"),Color::html("ffb609")};
    const double pixel=1.82*config.character_scale;
    for (const auto &gem:state.gems) if (gem.alive && view.grow(60).has_point(gem.pos))
        batch(config.crystal_visual,6,0).add(gem.seq,gem.pos,0,std::max(5.0,pixel*4.0)*1.4,crystal_colors[gem.kind]);
    for (size_t i=0;i<state.coins.size();++i) {
        const auto &coin=state.coins[i];if (coin.alive && view.grow(60).has_point(coin.pos))
            batch(config.coin_visual,6,-1).add(int64_t(i+1),coin.pos,0,std::max(6.0,pixel*3.5),Color::html("ffd24a"));
    }
    Array batches;for (auto &group:groups) if (!group.second.instances.empty()) batches.push_back(group.second.value());
    Array shapes;
    const auto &points=state.draw.drawing?state.draw.points:state.draw.path;
    if ((state.draw.drawing || state.draw.tracing) && points.size()>1) {
        Dictionary line;line["kind"]=0;line["layer"]=12;line["order"]=0;line["owner_id"]=0;line["points"]=points;
        PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(points.size());line["offsets"]=offsets;
        PackedFloat32Array widths;widths.push_back(pixel*2.0);line["widths"]=widths;
        PackedColorArray colors;colors.push_back(Color::html("8feaff"));line["colors"]=colors;shapes.push_back(line);
    }
    Array poses;
    Vector2 ship=state.ship.pos;double angle=state.ship.heading.angle();
    if (previous.ready) {ship=previous.ship_position.lerp(ship,alpha);angle=previous.ship_angle+angle_difference(angle-previous.ship_angle)*alpha;}
    const double recoil=state.forward.recoil>0?(state.forward.recoil>0.06?2.0:1.0)*pixel:0;
    const auto at=ship-state.ship.heading*recoil;
    const Transform2D transform(angle+godot::Math::PI/2.0,Vector2(config.character_scale,config.character_scale),0,at);
    int32_t visual_state=state.ship.hurt>0?1:0;
    if (state.ship.invuln>0 && std::fmod(state.time*20.0,2.0)<1.0) visual_state|=2;
    for (const auto visual:{config.cannon_visual,config.ship_visual}) {
        Dictionary pose;pose["participant_id"]=0;pose["part_key"]=visual;pose["transform"]=transform;
        pose["visible"]=state.phase!=godot::RunState::Phase::Ended && !(state.phase==godot::RunState::Phase::Dying && state.sequence_t>=state.death_freeze) && (visual!=config.cannon_visual || state.forward.ready);pose["visual_state"]=visual_state;poses.push_back(pose);
    }
    Dictionary out;out["schema_version"]=1;out["epoch"]=run.epoch;out["tick"]=state.control.tick;
    out["batches"]=batches;out["shapes"]=shapes;out["poses"]=poses;return out;
}
}
