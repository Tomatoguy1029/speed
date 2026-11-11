#include "../systems/heroes.h"
#include "../bosses/canis_major/body.h"
#include "../bosses/hydra/body.h"
#include "../behaviors/weapons/massTow.h"
#include "../behaviors/heroes/gemini.h"
#include "render_builder.h"
#include "../systems/boss_contact_feedback.h"
#include "../bosses/flow/technique_runner.h"
#include "../bosses/flow/phase_controller.h"
#include "../behaviors/enemies/crow.h"
#include "../systems/field.h"
#include "../systems/attack_system.h"
#include "../systems/attacks/beam.h"
#include "../systems/attacks/blast.h"
#include "../systems/attacks/wave.h"
#include "../systems/attacks/zone.h"
#include "../systems/attacks/flood.h"
#include "../systems/attacks/shell.h"
#include "../systems/attacks/wall.h"
#include "../systems/attacks/slash.h"
#include "../systems/attacks/bolt.h"
#include "../systems/attacks/star_bolt.h"
#include "../systems/attacks/light_arrow.h"
#include "../systems/attacks/friend_debris.h"
#include "../systems/attacks/friend_hull.h"
#include "../runtime/run_runtime.h"
#include "../systems/motion_math.h"
#include "../systems/group_system.h"
#include "../behaviors/enemies/sniper.h"
#include "../behaviors/enemies/pulser.h"
#include "../behaviors/enemies/aquarius.h"
#include "../behaviors/enemies/lynx.h"
#include "../state/boss_states.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include "../bosses/canis_major/state.h"
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <map>
#include <cmath>
namespace speed {
using namespace godot;
Dictionary RenderBatchBuffer::value() {
    ids.resize(instances.size());transforms.resize(instances.size()*6);colors.resize(instances.size());flags.resize(instances.size());
    auto *t=transforms.ptrw();auto *id=ids.ptrw();auto *color=colors.ptrw();auto *flag=flags.ptrw();
    bool deformed=false;
    for (size_t i=0;i<instances.size();++i) {
        const auto &v=instances[i];const float c=std::cos(v.angle)*v.radius,s=std::sin(v.angle)*v.radius;
        deformed=deformed || v.amount>0;
        id[i]=v.id;flag[i]=v.flags;color[i]=v.color;
        godot::Vector2 x(c,s),y(-s,c);
        if (v.deformation.length_squared()>0.0001) {const auto n=v.deformation.normalized(),side=godot::Vector2(-n.y,n.x);x=n*x.dot(n)*(1-0.5*v.amount)+side*x.dot(side)*(1+0.6*v.amount);y=n*y.dot(n)*(1-0.5*v.amount)+side*y.dot(side)*(1+0.6*v.amount);}
        t[i*6]=x.x;t[i*6+1]=x.y;t[i*6+2]=y.x;t[i*6+3]=y.y;t[i*6+4]=v.at.x;t[i*6+5]=v.at.y;
    }
    // 変形がなければ返さない配列は作らない。返す場合は全instanceの元の5要素順を保つ。
    PackedFloat32Array deformations;
    if (deformed) {
        deformations.resize(instances.size()*5);
        float *values=deformations.ptrw();
        for (size_t i=0;i<instances.size();++i) {
            const auto &v=instances[i];
            values[i*5]=float(v.radius);values[i*5+1]=float(v.angle);
            values[i*5+2]=v.deformation.x;values[i*5+3]=v.deformation.y;values[i*5+4]=float(v.amount);
        }
    }
    Dictionary out;if (deformed) out["deformations"]=deformations;out["visual_id"]=visual;out["layer"]=layer;out["order"]=order;out["ids"]=ids;
    out["transforms"]=transforms;out["colors"]=colors;out["flags"]=flags;
    if (!reference_bite_indices.is_empty()) out["reference_bite_indices"]=reference_bite_indices;
    if (biter) {Dictionary values;values["modes"]=modes;values["charges"]=charges;values["timers"]=timers;values["rests"]=rests;out["biter"]=values;}
    if (!ruler_sides.is_empty()) out["ruler_sides"]=ruler_sides;
    if (!marks.is_empty()) out["marks"]=marks;
    if (!glows.is_empty()) out["glows"]=glows;
    if (!gunner.is_empty()) out["gunner"]=gunner;
    if (!sniper.is_empty()) out["sniper"]=sniper;
    if (!dolphin.is_empty()) out["dolphin"]=dolphin;
    if (!lynx.is_empty()) out["lynx"]=lynx;
    if (!soldier.is_empty()) out["soldier"]=soldier;
    if (!reticle.is_empty()) out["reticle"]=reticle;
    if (!aquarius.is_empty()) out["aquarius"]=aquarius;
    if (!cross.is_empty()) out["cross"]=cross;
    if (!bomber.is_empty()) out["bomber"]=bomber;
    if (!crab.is_empty()) out["crab"]=crab;
    if (!pump.is_empty()) out["pump"]=pump;
    if (!battleship.is_empty()) out["battleship"]=battleship;
    if (!missile.is_empty()) out["missile"]=missile;
    if (!beamer.is_empty()) out["beamer"]=beamer;
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
    for (size_t i=0;i<state.friends.size();++i) {const auto &shot=state.friends[i];previous.friendly[i]={shot.alive?shot.id:0,shot.pos,shot.kind==int64_t(FriendKind::Shot)?double(shot.vel.angle()):double(shot.angle)};}
}
Dictionary RenderBuilder::read(const RunRuntime &run,Rect2 view,double alpha) {
    const auto &state=run.state;const auto &config=run.content->config;const auto &previous=state.previous_poses;
    auto &groups=run.render_workspace.batches;
    int64_t live_rows=0,batched_rows=0,marked_rows=0;
    for (auto &group:groups) {
        auto &out=group.second;out.instances.clear();out.biter=false;out.reference_bite_indices.clear();
        out.marks.clear();out.ruler_sides.clear();out.modes.clear();out.charges.clear();out.timers.clear();out.rests.clear();out.glows.clear();out.gunner.clear();out.beamer.clear();out.missile.clear();out.battleship.clear();out.sniper.clear();out.dolphin.clear();out.lynx.clear();out.soldier.clear();out.reticle.clear();out.aquarius.clear();out.cross.clear();out.bomber.clear();out.crab.clear();out.pump.clear();
    }
    PackedFloat32Array comet_values,crow_values,petrified_enemies,enemy_health,enemy_weak;
    Array lynx_actors,lynx_afterimages,lynx_fx,bite_fx,cross_actors,cross_beams,crab_fx,dolphin_actors,dolphin_waves,telescope_actors,reticle_fx,soldier_fx,soldier_bolts,hound_warning;
    const auto batch=[&](uint32_t visual,int32_t layer,int32_t order)->RenderBatchBuffer & {
        auto &out=groups[visual];out.visual=visual;out.layer=layer;out.order=order;return out;
    };
    for (uint32_t i=0;i<state.field.bodies.size();++i) {
        const auto &body=state.field.bodies[i];
        if (view.grow(body.radius).has_point(body.position)) batch(FieldSystem::visual(run,body),2,0).add(i+1,body.position,0,body.radius,Color(0,0,0,1));
    }
    for (size_t i=0;i<state.enemies.size();++i) {
        const auto &enemy=state.enemies[i];if (enemy.alive && !enemy.dead) ++live_rows;
        if (!enemy.alive || enemy.dead || enemy.clone_visual || enemy.picaro_owner.generation || (state.control.cinematic_hide_enemies && !enemy.is_boss)) continue;
        const auto &definition=run.content->definitions[enemy.definition];
        const bool hydra_part=HydraBody::owns_part(run,state.enemy_handles.at(i)) || (enemy.origin==SpawnOrigin::BossPart && definition.kind==EnemyDefinition::Kind::Drift);
        if (hydra_part && definition.kind!=EnemyDefinition::Kind::Meteor && view.grow(enemy.radius).has_point(enemy.pos)) {
            if ((enemy.is_boss || enemy.radius>=25.0) && enemy.max_hp>0 && enemy.hp<enemy.max_hp) for (float value:{enemy.pos.x,enemy.pos.y,float(enemy.radius),float(std::max(0.0,enemy.hp/enemy.max_hp))}) enemy_health.push_back(value);
            if (enemy.stone>0) for (float value:{enemy.pos.x,enemy.pos.y,float(enemy.radius)}) petrified_enemies.push_back(value);
        }
        if (!definition.visual_id || definition.kind==EnemyDefinition::Kind::Triangle || definition.kind==EnemyDefinition::Kind::Monoceros || definition.kind==EnemyDefinition::Kind::Centaurus || definition.kind==EnemyDefinition::Kind::CanisMajor || definition.kind==EnemyDefinition::Kind::Draco || definition.kind==EnemyDefinition::Kind::Hydra || hydra_part) continue;
        auto pose=interpolate(previous,{enemy.id,enemy.pos,enemy.facing},i,false,alpha);
        if (definition.kind==EnemyDefinition::Kind::Lynx) {
            const auto &motion=std::get<LynxState>(enemy.behavior_state);const auto &p=run.content->lynxes[definition.lynx_definition-1];
            if (motion.last_fire>=0 && state.world_time-motion.last_fire<p.fx_cut+0.06) for (int ghost=2;ghost>=1;--ghost) {
                const auto past=LynxBehavior::visual_pose(run,uint32_t(i),pose.position,pose.angle,state.world_time-ghost*0.025);
                Dictionary row;row["id"]=enemy.id;row["visual_id"]=definition.visual_id;row["pos"]=past.position;row["angle"]=past.facing+definition.sprite_angle;row["radius"]=enemy.radius*definition.sprite_scale;row["alpha"]=0.35/ghost;lynx_afterimages.push_back(row);
            }
            const auto fx=LynxBehavior::visual_pose(run,uint32_t(i),pose.position,pose.angle,state.world_time);pose.position=fx.position;pose.angle=fx.facing;
            if (enemy.charge>0) {Dictionary row;row["id"]=enemy.id;row["pos"]=pose.position;row["angle"]=pose.angle;row["radius"]=enemy.radius;row["charge"]=enemy.charge;row["side"]=motion.buds%2==0?1:-1;row["slash_size"]=p.slash_size;lynx_actors.push_back(row);}
        }
        if (definition.kind==EnemyDefinition::Kind::Aquarius) {
            const double time=AquariusBehavior::visual_time(run,uint32_t(i));
            if (time>=0) {const auto fx=AquariusBehavior::visual_pose(run,uint32_t(i),enemy.pos,enemy.facing,time);pose.position=fx.position;pose.angle=fx.facing;}
        }
        if (definition.kind==EnemyDefinition::Kind::Sniper && SniperBehavior::aiming(run,uint32_t(i))) {
            const auto &rays=std::get<SniperState>(enemy.behavior_state).rays;
            if (rays.size()==48) {
                const auto &p=run.content->snipers[definition.sniper_definition-1];
                Dictionary fx;fx["id"]=enemy.id;fx["pos"]=pose.position;fx["radius"]=enemy.radius;fx["angle"]=pose.angle;fx["windup"]=enemy.mode==EnemyMode::Windup;fx["charge"]=enemy.charge;fx["timer"]=enemy.timer;fx["laser_charge"]=p.laser_charge;fx["half"]=SniperBehavior::half(run,uint32_t(i));fx["band_narrow"]=p.band_narrow;fx["length"]=p.band_len;fx["seen"]=SniperBehavior::sight(run,uint32_t(i),state.ship_pos)==1;fx["ship_pos"]=state.ship_pos;PackedFloat32Array lengths;for (float v:rays) lengths.push_back(v);fx["rays"]=lengths;telescope_actors.push_back(fx);
            }
        }
        const bool meteor=definition.kind==EnemyDefinition::Kind::Meteor;
        const bool iron=definition.kind==EnemyDefinition::Kind::Obstacle && definition.id==StringName("iron");
        if (meteor && state.field.rock_handles.contains(enemy.rock) && state.field.rocks[enemy.rock.slot].kind==RockKind::Comet) {
            const auto &rock=state.field.rocks[enemy.rock.slot];
            // The tail extends 190 source pixels behind a core with a 15-pixel radius.
            if (view.grow(enemy.radius*14.0).has_point(pose.position)) {
                for (float value:{pose.position.x,pose.position.y,float(enemy.radius),enemy.vel.x,enemy.vel.y,
                        float(rock.rare_weapon!=0),float(state.world_time-rock.born)}) comet_values.push_back(value);
            }
            continue;
        }
        const double radius=meteor?FieldSystem::rock_sprite_radius(run,uint32_t(i)):enemy.radius*definition.sprite_scale;
        if (!view.grow(radius*1.4142135623730951).has_point(pose.position)) continue;
        if (enemy.stone>0) for (float v:{pose.position.x,pose.position.y,float(enemy.radius)}) petrified_enemies.push_back(v);
        if (!meteor && !iron && definition.kind!=EnemyDefinition::Kind::Shield && definition.weak_arc>0) {
            const bool native_sprite=definition.id==StringName("splitter") || definition.id==StringName("splitling");
            if (!native_sprite) for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(definition.weak_arc)}) enemy_weak.push_back(value);
        }
        if (!meteor && !iron && enemy.radius>=25.0 && enemy.max_hp>0 && enemy.hp<enemy.max_hp) for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(std::max(0.0,enemy.hp/enemy.max_hp))}) enemy_health.push_back(value);
        const bool body_visible=!(enemy.corona && enemy.corona->thrown && !definition.polygon_visual);
        auto &enemy_batch=batch(FieldSystem::rock_visual(run,uint32_t(i)),meteor?7:8,int32_t(enemy.definition));
        if (definition.kind==EnemyDefinition::Kind::Crow) {
            const auto cargo=CrowBehavior::cargo(run,state.enemy_handles.at(uint32_t(i)));
            if (cargo.amount>0) for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(cargo.amount),float(cargo.count)}) crow_values.push_back(value);
        }
        if (body_visible && definition.kind==EnemyDefinition::Kind::Biter) {
            enemy_batch.biter=true;enemy_batch.modes.push_back(int32_t(enemy.mode));enemy_batch.charges.push_back(enemy.charge);
            enemy_batch.timers.push_back(enemy.timer);enemy_batch.rests.push_back(definition.bite.rest);
        }
        if (definition.kind==EnemyDefinition::Kind::Hound || definition.kind==EnemyDefinition::Kind::Defender) {
            if (enemy.mode==EnemyMode::Windup && enemy.charge>0) {Dictionary fx;fx["id"]=enemy.id;fx["pos"]=pose.position;fx["angle"]=pose.angle;fx["radius"]=enemy.radius;fx["charge"]=enemy.charge;fx["kind"]=definition.kind==EnemyDefinition::Kind::Hound?"hound":"defender";bite_fx.push_back(fx);}
        }
        if (definition.kind==EnemyDefinition::Kind::Defender && enemy.charge>0) {
            enemy_batch.reference_bite_indices.push_back(enemy_batch.gunner.size()/5);
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge)}) enemy_batch.gunner.push_back(value);
        }
        if (body_visible && definition.kind==EnemyDefinition::Kind::Pump) {
            const auto &p=run.content->pumps[definition.pump_definition-1];const double base=definition.radius*(enemy.elite?1.25:1.0);const double full=std::clamp((enemy.radius/std::max(base,0.001)-1.0)/std::max(p.grow,0.001),0.0,1.0);const auto &v=std::get<PumpState>(enemy.behavior_state);
            for (float value:{pose.position.x,pose.position.y,float(pose.angle+definition.sprite_angle),float(base*definition.sprite_scale/18.5),float(enemy.mode==EnemyMode::Windup?1.0:full),float(double(v.contents.size())/p.store_max),float(state.world_time),float(std::min(1.0,enemy.flash*10.0)),enemy.mode==EnemyMode::Move && v.contents.size()<p.store_max?1.0f:0.0f}) enemy_batch.pump.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Crab) {
            const auto &p=run.content->crabs[definition.crab_definition-1];const auto c=definition.color;const auto &v=std::get<CrabState>(enemy.behavior_state);
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle+1.5707963267948966+(v.buds<0?3.141592653589793:0)),float(enemy.mode),float(enemy.charge),float(enemy.timer),float(p.open_time),float(p.reach),c.r,c.g,c.b,c.a,definition.polygon_visual?1.0f:0.0f}) enemy_batch.crab.push_back(value);
            if (enemy.mode==EnemyMode::Windup || enemy.mode==EnemyMode::Recover) {Dictionary fx;fx["pos"]=pose.position;fx["angle"]=pose.angle;fx["radius"]=enemy.radius;fx["charge"]=enemy.charge;fx["windup"]=enemy.mode==EnemyMode::Windup;fx["age"]=std::max(0.0,p.open_time-enemy.timer);crab_fx.push_back(fx);}
        }
        if (definition.kind==EnemyDefinition::Kind::Bomber && enemy.mode!=EnemyMode::Windup) {
            for (float v:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(0.7+0.3*std::sin(state.world_time*30.0+double(enemy.id)))}) enemy_batch.bomber.push_back(v);
        }
        if (definition.kind==EnemyDefinition::Kind::Cross && enemy.mode==EnemyMode::Windup) {
            const auto &p=run.content->cross_enemies[definition.cross_definition-1];const auto c=definition.color.lightened(0.2);
            for (float v:{pose.position.x,pose.position.y,float(enemy.radius),float(enemy.charge),float(p.beam_length),c.r,c.g,c.b,c.a}) enemy_batch.cross.push_back(v);
            Dictionary fx;fx["pos"]=pose.position;fx["radius"]=enemy.radius;fx["charge"]=enemy.charge;fx["length"]=p.beam_length;cross_actors.push_back(fx);
        }
        if (definition.kind==EnemyDefinition::Kind::Aquarius && enemy.charge>0) for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge)}) enemy_batch.aquarius.push_back(value);
        if (definition.kind==EnemyDefinition::Kind::Reticle) {
            const auto &target=std::get<ReticleState>(enemy.behavior_state);const bool valid=enemy.mode==EnemyMode::Windup && state.enemy_handles.contains(target.rock);
            const auto at=valid?state.enemies[target.rock.slot].pos:Vector2();const double radius=valid?state.enemies[target.rock.slot].radius:0;const auto color=definition.color.lightened(0.2);
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge),color.r,color.g,color.b,float(valid),at.x,at.y,float(radius)}) enemy_batch.reticle.push_back(value);
            if (valid) {Dictionary fx;fx["pos"]=pose.position;fx["radius"]=enemy.radius;fx["angle"]=pose.angle;fx["charge"]=enemy.charge;fx["target"]=at;fx["target_radius"]=radius;reticle_fx.push_back(fx);}
        }
        if (definition.kind==EnemyDefinition::Kind::Soldier) {
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.mode),float(enemy.charge),float(0.5+0.5*std::sin(state.world_time*30.0+double(enemy.id)))}) enemy_batch.soldier.push_back(value);
            if (enemy.charge>0) {const auto &v=std::get<SoldierState>(enemy.behavior_state);Dictionary fx;fx["pos"]=pose.position;fx["angle"]=pose.angle;fx["radius"]=enemy.radius;fx["charge"]=enemy.charge;fx["slot"]=v.slot;soldier_fx.push_back(fx);}
        }
        if (definition.kind==EnemyDefinition::Kind::Lynx && enemy.charge>0) {
            const float side=std::get<LynxState>(enemy.behavior_state).buds%2==0?1:-1;
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge),side}) enemy_batch.lynx.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Dolphin && enemy.mode==EnemyMode::Windup) {
            const auto &p=run.content->dolphins[definition.dolphin_definition-1];
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge),float(p.arc)}) enemy_batch.dolphin.push_back(value);
            Dictionary fx;fx["pos"]=pose.position;fx["radius"]=enemy.radius;fx["angle"]=pose.angle;fx["charge"]=enemy.charge;fx["arc"]=p.arc;dolphin_actors.push_back(fx);
        }
        if (definition.kind==EnemyDefinition::Kind::Sniper && SniperBehavior::aiming(run,uint32_t(i))) {
            const auto &rays=std::get<SniperState>(enemy.behavior_state).rays;
            if (rays.size()==48) {
                const auto &p=run.content->snipers[definition.sniper_definition-1];
                for (float v:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.mode),float(enemy.charge),float(enemy.timer),float(p.laser_charge),float(SniperBehavior::half(run,uint32_t(i))),float(p.band_len),float(SniperBehavior::sight(run,uint32_t(i),state.ship_pos)==1)}) enemy_batch.sniper.push_back(v);
                for (float v:rays) enemy_batch.sniper.push_back(v);
            }
        }
        if (definition.kind==EnemyDefinition::Kind::Battleship && (enemy.charge>0 || definition.weak_arc>0)) {
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge),0.0f}) enemy_batch.battleship.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Missile && enemy.charge>0) {
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge)}) enemy_batch.missile.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Beamer) {
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.mode),float(enemy.charge),definition.color.r,definition.color.g,definition.color.b,definition.color.a}) enemy_batch.beamer.push_back(value);
        }
        if (body_visible) if (const auto *ruler=std::get_if<RulerState>(&enemy.behavior_state)) enemy_batch.ruler_sides.push_back(ruler->side);
        bool relay_warning=false;
        if (definition.kind==EnemyDefinition::Kind::Hound && GroupSystem::warning(state,state.enemy_handles.at(uint32_t(i))))
            for (const auto &technique:state.bosses->techniques) if (const auto *relay=technique.detail.get_if<CanisRelayState>(); relay && technique.stage<TechniqueStage::Finished && !relay->cancelled && !relay->aiming)
                for (const auto &item:relay->items) if (item.marked && !item.fired && same_handle(item.actor,state.enemy_handles.at(uint32_t(i)))) relay_warning=true;
        const bool warning=definition.kind==EnemyDefinition::Kind::Hound && !relay_warning && GroupSystem::warning(state,state.enemy_handles.at(uint32_t(i)));
        if (warning) {
            const auto *order=GroupSystem::order(state,state.enemy_handles.at(uint32_t(i)));const auto delta=state.ship_pos-pose.position;Dictionary fx;
            fx["id"]=enemy.id;fx["position"]=pose.position;fx["radius"]=enemy.radius;fx["sprite_radius"]=radius;fx["facing"]=delta.length_squared()>0.000001?double(delta.angle()):pose.angle;
            fx["progress"]=order?std::clamp((state.world_time-order->warning_started)/std::max(0.000001,order->warning_until-order->warning_started),0.0,1.0):0.0;
            fx["started_at"]=order?order->warning_started:state.world_time;fx["until"]=order?order->warning_until:state.world_time;fx["visual_id"]=FieldSystem::rock_visual(run,uint32_t(i));hound_warning.push_back(fx);continue;
        }
        if (!body_visible) continue;
        auto color=definition.polygon_visual?(enemy.flash>0?Color(1,1,1,1):CanisMajorBody::color(run,state.enemy_handles.at(i),definition.color)):Color(!meteor && (enemy.flash>0 || warning)?1.0:0.0,0,0,1);
        if (definition.kind==EnemyDefinition::Kind::Bomber && enemy.mode==EnemyMode::Windup) color.g=std::fmod(enemy.charge*3.0,1.0)>=0.45?1.0:0.0;
        godot::Vector2 deform;double amount=0;bool flash=false;
        for (const auto &w:state.loadout->contact_wave.waves) for (const auto &h:w.caught) if (h.id==enemy.id && state.enemy_handles.contains(h.target)) {const double p=std::clamp(h.age/0.16,0.0,1.0);deform=enemy.pos-w.pos;amount=std::sin(p*3.141592653589793);flash=p<0.45;}
        if (flash) color.r=1;
        // ペルセウス座で石になった敵：色の b に石になってからの秒を渡し、絵を石の灰色へ置き換える
        if (!definition.polygon_visual && enemy.stone>0 && !run.content->perseus.empty()) color.b=std::clamp(run.content->perseus.front().shatter_delay+0.5-enemy.stone,0.004,1.0);
        enemy_batch.add(enemy.id,pose.position,pose.angle+definition.sprite_angle,radius,iron?Color(0,0,0,1):color,iron?int32_t((state.field.rock_handles.contains(enemy.rock)?int64_t(enemy.rock.slot):enemy.id)%3):(enemy.flash>0 || warning || flash?1:0));
        const auto *parent=state.enemy_handles.contains(enemy.parent)?&state.enemies[enemy.parent.slot]:nullptr;
        enemy_batch.marks.push_back((enemy.landmark || (parent && parent->landmark)?1:0) | (enemy.elite || (parent && parent->elite)?2:0));
        ++batched_rows;if (enemy_batch.marks[enemy_batch.marks.size()-1]) ++marked_rows;
        enemy_batch.instances.back().deformation=deform;enemy_batch.instances.back().amount=amount;
    }
    for (size_t i=0;i<state.friends.size();++i) {
        const auto &shot=state.friends[i];if (!shot.alive || shot.kind!=int64_t(FriendKind::Shot)) continue;
        const auto pose=interpolate(previous,{shot.id,shot.pos,shot.kind!=int64_t(FriendKind::Shot)?double(shot.angle):double(shot.vel.angle())},i,true,alpha);
        const bool saw=shot.kind==2 && shot.type==StringName("saw");
        const double radius=saw?double(shot.radius):18.0*1.82*config.character_scale;
        if (!view.grow(radius).has_point(pose.position)) continue;
        if (saw && !run.content->rock_fields.empty()) batch(run.content->definitions[run.content->rock_fields.front().saw-1].visual_id,10,0).add(shot.id,pose.position,pose.angle,radius,Color(0,0,0,1));
        else batch(config.shot_visual,10,0).add(shot.id,pose.position,pose.angle,1.82*config.character_scale,Color(1,1,1,1),shot.visual==StringName("weapon/interceptor")?3:shot.visual==StringName("weapon/scatter")?(shot.life<0.09?2:1):0);
    }
    for (uint32_t row=0;row<state.hostiles.size();++row) {
        const auto &shot=state.hostiles[row];
        if (shot.alive && shot.star_bolt.definition && view.has_point(shot.pos)) {
            const auto &d=run.content->star_bolts[shot.star_bolt.definition-1];StarBoltSystem::render(run,row,batch(d.visual,10,0),batch(d.stone_visual,10,1));continue;
        }
        if (!shot.alive || !shot.definition || !view.grow(40.0).has_point(shot.pos)) continue;
        const auto &definition=run.content->hostile_definitions[shot.definition-1];const auto *record=AttackSystem::get(state,shot.attack);if (!record) continue;if (record->spec.source_technique && run.content->boss_techniques[record->spec.source_technique-1].kind==83) continue;
        batch(definition.visual,10,0).add(record->id,shot.pos,shot.kind==int64_t(HostileKind::Reflected)?shot.vel.angle():0.0,shot.radius,Color(1,1,1,1));
        if (shot.stone>0) batch(definition.stone_visual,10,1).add(record->id,shot.pos,0,shot.radius*1.3,Color(0.62,0.6,0.58,0.9));
    }
    const Color crystal_colors[]={Color::html("08deff"),Color::html("945cff"),Color::html("ffb609")};
    const double pixel=1.82*config.character_scale;
    for (auto row:state.pickups.nearest_gems(view.grow(128),state.ship.pos,size_t(state.pickup_config.gem_draw_max))) {
        const auto &gem=state.pickups.gems[row];
        batch(config.crystal_visual,6,0).add(int64_t(gem.id),gem.pos,0,std::max(5.0,pixel*4.0)*0.7,crystal_colors[gem.kind]);
    }
    for (size_t i=0;i<state.pickups.coins.size();++i) {
        const auto &coin=state.pickups.coins[i];if (coin.alive && view.grow(60).has_point(coin.pos))
            batch(config.coin_visual,6,-1).add(int64_t(i+1),coin.pos,0,std::max(6.0,pixel*3.5),Color::html("ffd24a"));
    }
    PackedFloat64Array pulser;
    for (uint32_t i=0;i<state.enemies.size();++i) {
        const auto &e=state.enemies[i];if (!e.alive || e.dead || (state.control.cinematic_hide_enemies && !e.is_boss) || e.held || e.stone>0 || state.enemy_handles.contains(e.pump_owner) || e.mode!=EnemyMode::Windup) continue;
        const auto &d=run.content->definitions[e.definition];if (d.kind!=EnemyDefinition::Kind::Pulser) continue;
        const auto &p=run.content->pulsers[d.pulser_definition-1];const double radius=PulserBehavior::ring_radius(run,i);
        if (!view.grow(radius+p.width*26).has_point(e.pos)) continue;
        for (double value:{double(e.pos.x),double(e.pos.y),radius,p.width,1.0-std::clamp(e.timer/std::max(p.warn,0.001),0.0,1.0),double(e.id%4093)}) pulser.push_back(value);
    }
    Dictionary crows;crows["time"]=state.world_time;crows["values"]=crow_values;
    Dictionary comets;comets["values"]=comet_values;
    Dictionary capsules;PackedFloat32Array capsule_values;for (const auto &cap:state.pickups.capsules) for (float value:{cap.pos.x,cap.pos.y,float(cap.kind)}) capsule_values.push_back(value);capsules["time"]=state.time;capsules["values"]=capsule_values;
    Dictionary warp;warp["position"]=state.field.warp_pos;warp["gone"]=state.field.warp_gone;warp["radius"]=run.content->warp.radius;warp["time"]=state.world_time;
    Dictionary gravity;PackedFloat64Array well_values;
    for (const auto &well:state.field.wells) for (double value:{double(well.position.x),double(well.position.y),well.born,well.life,well.radius}) well_values.push_back(value);
    gravity["time"]=state.world_time;gravity["wells"]=well_values;
    PackedFloat64Array ruler;Array ruler_fx;
    for (size_t i=0;i<state.enemies.size();++i) {
        const auto &e=state.enemies[i];
        if (!e.alive || e.dead || state.control.cinematic_hide_enemies || !std::holds_alternative<RulerState>(e.behavior_state)) continue;
        const auto &d=run.content->definitions[e.definition];const auto &p=run.content->rulers[d.ruler_definition-1];const auto color=d.color.lightened(0.2);
        for (double value:{double(e.pos.x),double(e.pos.y),e.radius,e.facing,double(e.mode),e.charge,p.beam_len,p.beam_width,p.beam_start_gap,double(color.r),double(color.g),double(color.b)}) ruler.push_back(value);
        const auto &ruler_state=std::get<RulerState>(e.behavior_state);if (!ruler_state.side || (e.mode!=EnemyMode::Windup && e.mode!=EnemyMode::Recover)) continue;
        const auto pose=interpolate(previous,{e.id,e.pos,e.facing},i,false,alpha);
        const auto direction=Vector2::from_angle(pose.angle),normal=Vector2(-direction.y,direction.x);const double scale=2*e.radius*d.sprite_scale/58.0;
        Dictionary fx;fx["id"]=e.id;fx["side"]=ruler_state.side;fx["pos"]=pose.position+direction*(27.5*scale+p.fx_muzzle)+normal*(ruler_state.side*10.5*scale);fx["angle"]=pose.angle;fx["radius"]=e.radius;fx["charge"]=e.charge;fx["length"]=p.beam_len;fx["width"]=p.beam_width;fx["windup"]=e.mode==EnemyMode::Windup;fx["time"]=std::max(0.0,p.beam_time-e.timer);fx["active"]=p.beam_time;
        if (const auto *record=AttackSystem::get(state,ruler_state.beam)) {const auto &hazard=state.hazards[record->row];fx["order"]=record->id;fx["time"]=double(hazard.time);fx["active"]=double(hazard.duration);}
        ruler_fx.push_back(fx);
    }
    Array auriga_trails;
    for (const auto &h:state.hazards) {const auto *wall=std::get_if<WallHazard>(&h.shape);const auto *record=AttackSystem::get(state,h.attack);
        if (!h.alive || !wall || !record || wall->trail_visual_owner<=0) continue;
        Dictionary fx;fx["owner_id"]=wall->trail_visual_owner;fx["side"]=wall->trail_visual_side;fx["order"]=record->id;fx["from"]=h.pos;fx["to"]=h.pos+Vector2::from_angle(wall->angle)*wall->length;fx["width"]=double(wall->half_width)*2;fx["age"]=double(h.time);fx["life"]=double(h.duration);auriga_trails.push_back(fx);
    }
    PackedFloat64Array triangle_star;
    for (const auto &h:state.hazards) {const auto *w=std::get_if<WallHazard>(&h.shape);const auto *record=AttackSystem::get(state,h.attack);
        if (!h.alive || !w || w->style!=uint32_t(WallStyle::Trail) || !record || !state.enemy_handles.contains(record->spec.owner.live_source)) continue;
        const auto &owner=state.enemies[record->spec.owner.live_source.slot];if (state.control.cinematic_hide_enemies || owner.dead || run.content->definitions[owner.definition].kind!=EnemyDefinition::Kind::TriangleStar) continue;
        const auto head=h.pos+Vector2::from_angle(w->angle)*w->length;for (double value:{double(h.pos.x),double(h.pos.y),double(head.x),double(head.y),double(w->half_width)*2}) triangle_star.push_back(value);
    }
    Dictionary cepheus;PackedFloat64Array cepheus_values,cepheus_marks;Array cepheus_fx,cepheus_actors;
    for (const auto &e:state.enemies) if (e.alive && !e.dead && !state.control.cinematic_hide_enemies && std::holds_alternative<CepheusState>(e.behavior_state) && e.mode==EnemyMode::Windup) {for (double v:{double(e.pos.x),double(e.pos.y),e.radius,e.facing,e.charge}) cepheus_values.push_back(v);Dictionary fx;fx["pos"]=e.pos;fx["radius"]=e.radius;fx["angle"]=e.facing;fx["charge"]=e.charge;cepheus_actors.push_back(fx);}
    for (const auto &m:state.groups.summon_marks) {if (state.control.cinematic_hide_enemies) continue;const double age=m.age;if (age>=m.life) continue;for (double v:{double(m.pos.x),double(m.pos.y),double(m.king.x),double(m.king.y),double(m.color.r),double(m.color.g),double(m.color.b),double(m.color.a),age/m.life,state.world_time}) cepheus_marks.push_back(v);}
    for (const auto &m:state.groups.summon_marks) {if (state.control.cinematic_hide_enemies || m.age>=m.life || !m.visual_owner || !m.visual_id) continue;Dictionary fx;fx["id"]=m.visual_owner;fx["tick"]=m.visual_tick;fx["slot"]=m.visual_slot;fx["pos"]=m.pos;fx["from"]=m.king;fx["age"]=m.age;fx["life"]=m.life;fx["angle"]=m.visual_angle;fx["radius"]=m.visual_radius;fx["sprite_radius"]=m.visual_sprite_radius;fx["visual_id"]=m.visual_id;cepheus_fx.push_back(fx);}
    cepheus["values"]=cepheus_values;cepheus["marks"]=cepheus_marks;
    PackedFloat64Array corona,corona_members;Array corona_selected,corona_thrown;
    for (const auto &e:state.enemies) {
        if (!e.alive || e.dead || (state.control.cinematic_hide_enemies && !e.is_boss)) continue;
        if (const auto *o=std::get_if<CoronaState>(&e.behavior_state)) if (o->ready && view.grow(200).has_point(e.pos)) {const auto &p=run.content->coronas[run.content->definitions[e.definition].corona_definition-1];for (double v:{double(e.pos.x),double(e.pos.y),p.ring,state.world_time*p.spin,e.radius,double(e.mode),e.charge}) corona.push_back(v);}
        if (e.corona && view.grow(400).has_point(e.pos)) {
            const auto &a=*e.corona;const bool has_owner=state.enemy_handles.contains(a.owner);
            if (!has_owner && !a.thrown) continue;
            const auto *owner=has_owner?&state.enemies[a.owner.slot]:nullptr;
            const auto *o=owner?std::get_if<CoronaState>(&owner->behavior_state):nullptr;
            const bool selected=o && state.enemy_handles.contains(o->selected) && state.enemy_handles.entity_id(o->selected)==e.id;
            const auto origin=owner?owner->pos:e.pos;
            for (double v:{double(e.pos.x),double(e.pos.y),e.radius*a.effect,a.thrown?1.0:0.0,double(e.vel.x),double(e.vel.y),selected?1.0:0.0,double(origin.x),double(origin.y),state.world_time}) corona_members.push_back(v);
            const auto &d=run.content->definitions[e.definition];
            if (selected && !a.thrown) {Dictionary fx;fx["id"]=e.id;fx["pos"]=e.pos;fx["from"]=origin;fx["radius"]=e.radius*a.effect;fx["sprite_radius"]=e.radius*d.sprite_scale;fx["angle"]=e.facing;fx["charge"]=owner->charge;fx["visual_id"]=d.visual_id;corona_selected.push_back(fx);}
            if (a.thrown) {const auto &p=run.content->coronas[run.content->definitions[owner?owner->definition:a.slot].corona_definition-1];Dictionary fx;fx["id"]=e.id;fx["pos"]=e.pos;fx["velocity"]=e.vel;fx["radius"]=e.radius;fx["sprite_radius"]=e.radius*d.sprite_scale;fx["angle"]=e.facing;fx["seed_angle"]=a.angle;fx["age"]=std::max(0.0,p.throw_life-a.life);fx["life"]=p.throw_life;fx["visual_id"]=d.visual_id;fx["polygon"]=d.polygon_visual;corona_thrown.push_back(fx);}
        }
    }
    Dictionary aquila;PackedFloat64Array aquila_values;Array aquila_actors,aquila_zones;
    for (const auto &e:state.enemies) {
        if (!e.alive || e.dead || (state.control.cinematic_hide_enemies && !e.is_boss)) continue;const auto &d=run.content->definitions[e.definition];if (d.kind!=EnemyDefinition::Kind::Aquila) continue;
        const auto &p=run.content->aquilas[d.aquila_definition-1];const auto &a=std::get<AquilaState>(e.behavior_state);const auto center=a.anchor;
        if (e.mode==EnemyMode::Windup) for (double v:{double(e.pos.x),double(e.pos.y),e.radius,e.charge,double(center.x),double(center.y),p.dash_speed*p.drop_step,p.blast_radius,e.held || e.stone>0?0.0:1.0}) aquila_values.push_back(v);
        Dictionary fx;fx["id"]=e.id;fx["pos"]=e.pos;fx["angle"]=e.facing;fx["radius"]=e.radius;fx["sprite_radius"]=e.radius*d.sprite_scale;fx["visual_id"]=d.visual_id;fx["mode"]=int32_t(e.mode);fx["charge"]=e.charge;fx["anchor"]=center;fx["step"]=p.dash_speed*p.drop_step;fx["blast_radius"]=p.blast_radius;fx["enabled"]=!e.held && e.stone<=0;Array trace;for (const auto &point:a.trace) {Dictionary t;t["pos"]=point.pos;t["time"]=point.time;trace.push_back(t);}fx["trace"]=trace;aquila_actors.push_back(fx);
    }
    for (const auto &h:state.hazards) {if (!h.alive || !h.aquila_seed || !h.zone_definition) continue;const auto *circle=std::get_if<CircleHazard>(&h.shape);const auto *record=AttackSystem::get(state,h.attack);if (!circle || !record) continue;Dictionary fx;fx["order"]=record->id;fx["pos"]=h.pos;fx["radius"]=double(circle->radius);fx["time"]=double(h.time);fx["delay"]=double(h.delay);fx["active"]=double(h.duration);fx["seed"]=h.aquila_seed;aquila_zones.push_back(fx);}
    aquila["values"]=aquila_values;aquila["view"]=view;
    PackedFloat64Array phoenix;
    Array phoenix_fx,phoenix_impacts;
    for (size_t i=0;i<state.enemies.size();++i) {
        const auto &e=state.enemies[i];
        if (!e.alive || e.dead || (state.control.cinematic_hide_enemies && !e.is_boss) || (e.mode!=EnemyMode::Windup && e.mode!=EnemyMode::Dash)) continue;const auto &d=run.content->definitions[e.definition];if (d.kind!=EnemyDefinition::Kind::Phoenix) continue;
        const auto &p=run.content->phoenixes[d.phoenix_definition-1];const auto center=std::get<PhoenixState>(e.behavior_state).anchor;const double radius=std::max(e.radius*1.1,p.impact_radius);
        const auto pose=interpolate(previous,{e.id,e.pos,e.facing},i,false,alpha);
        const bool diving=e.mode==EnemyMode::Dash;
        Dictionary fx;fx["id"]=e.id;fx["mode"]=diving?"dash":"windup";fx["pos"]=pose.position;fx["anchor"]=center;
        fx["radius"]=e.radius;fx["facing"]=pose.angle;fx["sprite_radius"]=e.radius*d.sprite_scale;fx["sprite_angle"]=pose.angle+d.sprite_angle;fx["retreat_time"]=p.retreat_time;fx["impact_radius"]=radius;
        fx["telegraph_progress"]=diving?1.0:e.charge;fx["dive_progress"]=diving?std::clamp(1.0-e.timer/p.dive_time,0.0,1.0):0.0;
        fx["telegraph_elapsed"]=diving?p.telegraph+std::clamp(p.dive_time-e.timer,0.0,p.dive_time):std::clamp(p.telegraph-e.timer,0.0,p.telegraph);
        phoenix_fx.push_back(fx);
        if (!view.grow(radius*3).has_point(center)) continue;
        for (double v:{double(center.x),double(center.y),e.radius,e.facing,radius,e.mode==EnemyMode::Windup?e.charge:1.0,double(e.id%31)/31.0}) phoenix.push_back(v);
    }
    for (const auto &h:state.hazards) {
        if (!h.alive || !h.zone_definition || h.time<h.delay) continue;
        const auto &zone=run.content->zones[h.zone_definition-1];if (zone.style!=uint32_t(ZoneStyle::Phoenix)) continue;
        const auto *circle=std::get_if<CircleHazard>(&h.shape);const auto *record=AttackSystem::get(state,h.attack);if (!circle || !record) continue;
        Dictionary impact;impact["order"]=record->id;impact["owner_id"]=record->spec.owner.source_id;impact["pos"]=h.pos;impact["radius"]=double(circle->radius);impact["age"]=std::max(0.0,double(h.time-h.delay));phoenix_impacts.push_back(impact);
    }
    Array beamer_fx,telescope_beams,aquarius_jets;
    for (const auto &h:state.hazards) {
        const auto *wave=std::get_if<WaveHazard>(&h.shape);const auto *record=AttackSystem::get(state,h.attack);
        if (!h.alive || !wave || !record || wave->style!=uint32_t(WaveStyle::Ripple)) continue;
        Dictionary fx;fx["order"]=record->id;fx["pos"]=h.pos;fx["angle"]=double(wave->angle);fx["arc"]=double(wave->arc);fx["radius"]=double(wave->radius);fx["speed"]=double(wave->speed);fx["width"]=double(wave->half_width)*2;fx["time"]=std::max(0.0,double(h.time-h.delay));dolphin_waves.push_back(fx);
    }
    for (const auto &h:state.hazards) {
        if (!h.alive) continue;
        const auto *beam=std::get_if<BeamHazard>(&h.shape);const auto *record=AttackSystem::get(state,h.attack);
        if (!beam || !record) continue;
        const auto source=record->spec.owner.source_definition;
        if (!source || source>run.content->definitions.size()) continue;
        const auto kind=run.content->definitions[source-1].kind;
        if (kind==EnemyDefinition::Kind::Aquarius && beam->style==uint32_t(BeamStyle::Flood)) {
            const auto owner=record->spec.owner.live_source;Dictionary fx;fx["order"]=record->id;fx["pos"]=h.pos;fx["angle"]=double(beam->angle);fx["length"]=double(beam->length);fx["half_width"]=double(beam->half_width);fx["spread"]=double(beam->arc);fx["time"]=double(h.time);fx["delay"]=double(h.delay);fx["active"]=double(h.duration);fx["index"]=beam->flood_index;fx["radius"]=state.enemy_handles.contains(owner)?state.enemies[owner.slot].radius:run.content->definitions[source-1].radius;aquarius_jets.push_back(fx);continue;
        }
        if (kind==EnemyDefinition::Kind::Sniper && beam->style==uint32_t(BeamStyle::Telescope)) {
            Dictionary fx;fx["order"]=record->id;fx["pos"]=h.pos;fx["angle"]=double(beam->angle);fx["length"]=double(beam->length);fx["half_width"]=double(beam->half_width);fx["time"]=double(h.time);fx["delay"]=double(h.delay);fx["active"]=double(h.duration);telescope_beams.push_back(fx);continue;
        }
        if (kind==EnemyDefinition::Kind::Cross && beam->style==uint32_t(BeamStyle::Plain)) {
            Dictionary fx;fx["order"]=record->id;fx["owner_id"]=record->spec.owner.source_id;fx["pos"]=h.pos;fx["angle"]=double(beam->angle);fx["length"]=double(beam->length);fx["half_width"]=double(beam->half_width);fx["time"]=double(h.time);fx["delay"]=double(h.delay);fx["active"]=double(h.duration);cross_beams.push_back(fx);continue;
        }
        if (kind!=EnemyDefinition::Kind::Beamer || beam->style!=uint32_t(BeamStyle::Guide)) continue;
        const auto owner=record->spec.owner.live_source;
        Dictionary fx;fx["order"]=record->id;fx["owner_id"]=record->spec.owner.source_id;fx["pos"]=h.pos;
        fx["angle"]=double(beam->angle);fx["length"]=double(beam->length);fx["half_width"]=double(beam->half_width);fx["owner_alive"]=state.enemy_handles.contains(owner);fx["enemy_radius"]=state.enemy_handles.contains(owner)?state.enemies[owner.slot].radius:run.content->definitions[source-1].radius;
        fx["time"]=double(h.time);fx["delay"]=double(h.delay);fx["active"]=double(h.duration);beamer_fx.push_back(fx);
    }
    for (const auto &shot:state.hostiles) {
        if (shot.alive && shot.bolt.reference_soldier && shot.bolt.definition && shot.bolt.definition<=run.content->bolts.size()) {Dictionary fx;fx["pos"]=shot.pos;fx["angle"]=shot.vel.angle();fx["age"]=std::max(0.0,run.content->bolts[shot.bolt.definition-1].life-double(shot.life));fx["speed"]=shot.speed;soldier_bolts.push_back(fx);}
        if (!shot.alive || !shot.slash.lynx_definition) continue;
        const auto *record=AttackSystem::get(state,shot.attack);if (!record) continue;
        Dictionary fx;fx["id"]=record->id;fx["pos"]=shot.pos;fx["angle"]=double(shot.vel.angle());fx["side"]=double(shot.slash.side);fx["size"]=double(shot.radius);fx["age"]=shot.slash.age;fx["paw"]=shot.slash.paw_offset;lynx_fx.push_back(fx);
    }
    Dictionary marlin;PackedInt64Array marlin_ids;PackedFloat64Array marlin_values;
    for (size_t i=0;i<state.enemies.size();++i) {
        const auto &e=state.enemies[i];if (!e.alive || e.dead || (state.control.cinematic_hide_enemies && !e.is_boss) || e.held || e.stone>0) continue;const auto &d=run.content->definitions[e.definition];if (d.kind!=EnemyDefinition::Kind::Marlin) continue;
        const auto &p=run.content->marlins[d.marlin_definition-1];const auto direction=Vector2::from_angle(e.facing),from=e.pos+direction*e.radius;auto to=e.pos+direction*p.dash_speed*p.dash_time;
        if (const auto hit=FieldSystem::first_body_hit(run,e.pos,to,e.radius)) to=e.pos.lerp(to,hit->t);
        marlin_ids.push_back(e.id);for (double v:{double(e.pos.x),double(e.pos.y),e.facing,e.radius,e.radius*d.sprite_scale,d.sprite_angle+e.facing,double(e.mode),e.charge,e.timer,p.dash_time,double(from.x),double(from.y),double(to.x),double(to.y)}) marlin_values.push_back(v);
    }
    marlin["ids"]=marlin_ids;marlin["values"]=marlin_values;marlin["view"]=view;
    Array batches;for (auto &group:groups) if (!group.second.instances.empty()) batches.push_back(group.second.value());
    Array shapes;
    MassTowBehavior::render(run,view,shapes);
    for (uint32_t row=0;row<state.friends.size();++row) {FriendDebrisSystem::render(run,row,view,shapes,alpha);FriendHullSystem::render(run,row,view,shapes,alpha);}
    for (uint32_t row=0;row<state.hazards.size();++row) {BeamSystem::render(run,row,view,shapes);WaveSystem::render(run,row,view,shapes);WallSystem::render(run,row,view,shapes);BlastSystem::render(run,row,view,shapes);ZoneSystem::render(run,row,view,shapes);FloodSystem::render(run,row,view,shapes);}
    for (uint32_t row=0;row<state.hostiles.size();++row) {SlashSystem::render(run,row,view,shapes);BoltSystem::render(run,row,view,shapes);LightArrowSystem::render(run,row,view,shapes);ShellSystem::render(run,row,view,shapes);}
    const auto &points=state.draw.drawing?state.draw.points:state.draw.path;
    // ふたご座の間は、光と影の線を表示側（heroes.gd）が描くので、通常のなぞり線を出さない
    if ((state.draw.drawing || state.draw.tracing) && points.size()>1 && !GeminiBehavior::active(run)) {
        const double radius=config.trace_radius;
        Dictionary band;band["kind"]=int(RenderShapeKind::Polyline);band["layer"]=3;band["order"]=0;band["owner_id"]=0;band["points"]=points;band["rounded"]=true;
        PackedInt32Array band_offsets;band_offsets.push_back(0);band_offsets.push_back(points.size());band["offsets"]=band_offsets;
        PackedFloat32Array band_widths;band_widths.push_back(radius*2);band["widths"]=band_widths;
        PackedColorArray band_colors;band_colors.push_back(Color(0.55,0.9,1));band["colors"]=band_colors;shapes.push_back(band);
        Dictionary joints;joints["kind"]=int(RenderShapeKind::Circle);joints["layer"]=3;joints["order"]=1;joints["owner_id"]=0;joints["points"]=points;
        PackedInt32Array joint_offsets;PackedFloat32Array joint_radii;PackedColorArray joint_colors;
        for (int64_t i=0;i<points.size();++i) {joint_offsets.push_back(i);joint_radii.push_back(radius);joint_colors.push_back(band_colors[0]);}joint_offsets.push_back(points.size());joints["offsets"]=joint_offsets;joints["widths"]=joint_radii;joints["colors"]=joint_colors;shapes.push_back(joints);
        Dictionary line;line["kind"]=0;line["layer"]=12;line["order"]=0;line["owner_id"]=0;line["points"]=points;
        PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(points.size());line["offsets"]=offsets;
        PackedFloat32Array widths;widths.push_back(pixel*2.0);line["widths"]=widths;
        PackedColorArray colors;colors.push_back(Color::html("8feaff"));line["colors"]=colors;shapes.push_back(line);
    }
    Array poses;
    Vector2 ship=state.ship.pos;double angle=state.ship.heading.angle();
    if (previous.ready) {ship=previous.ship_position.lerp(ship,alpha);angle=previous.ship_angle+angle_difference(angle-previous.ship_angle)*alpha;}
    const double forward_recoil=state.forward.recoil>0?(state.forward.recoil>0.06?2.0:1.0)*pixel:0;
    const auto &scatter=state.loadout->scatter;
    const double scatter_recoil=scatter.recoil>0?(scatter.recoil>0.035?2.0:1.0)*pixel:0;
    const auto at=ship-state.ship.heading*std::max(forward_recoil,scatter_recoil);
    const Transform2D transform(angle+godot::Math::PI/2.0,Vector2(config.character_scale,config.character_scale),0,at);
    int32_t visual_state=state.ship.hurt>0?1:0;
    if (boss_contact_white(run)) visual_state|=4;
    if ((state.ship.invuln>0 || !state.ship.attacker_invuln.empty()) && std::fmod(state.time*20.0,2.0)<1.0) visual_state|=2;
    for (const auto visual:{config.cannon_visual,config.ship_visual}) {
        Dictionary pose;pose["participant_id"]=0;pose["part_key"]=visual;pose["transform"]=transform;
        pose["visible"]=state.phase!=godot::RunState::Phase::Ended && !state.control.cinematic_hide_ship && !(state.phase==godot::RunState::Phase::Dying && state.sequence_t>=state.death_freeze) && (visual!=config.cannon_visual || state.forward.ready || scatter.ready);pose["visual_state"]=visual_state;poses.push_back(pose);
    }
    Dictionary boss_ram;const auto &ram=state.control.boss_ram;
    if (ram.serial>0) {boss_ram["pending"]=ram.pending;boss_ram["serial"]=ram.serial;boss_ram["id"]=ram.target_id;boss_ram["entry"]=ram.entry;boss_ram["exit"]=ram.exit;boss_ram["direction"]=ram.direction;boss_ram["remaining"]=ram.remaining;boss_ram["started_at"]=ram.started_at;boss_ram["released_at"]=ram.released_at;boss_ram["clock"]=state.sim_time;}
    if (ram.serial>0) {boss_ram["cut_exit"]=ram.exit-ram.direction*(state.ship_config.ship_radius+4.0);int64_t body_id=0;for (const auto &body:state.bosses->bodies) if (same_handle(body.actor,ram.target)) {body_id=body.id;break;}boss_ram["body_id"]=body_id;}
    Dictionary out;out["schema_version"]=1;out["epoch"]=run.epoch;out["tick"]=state.control.tick;out["boss_ram"]=boss_ram;
    out["crab_fx"]=crab_fx;out["ruler_fx"]=ruler_fx;out["dolphin_actors"]=dolphin_actors;out["dolphin_waves"]=dolphin_waves;out["auriga_trails"]=auriga_trails;out["telescope_beams"]=telescope_beams;out["telescope_actors"]=telescope_actors;out["reticle_fx"]=reticle_fx;out["aquarius_jets"]=aquarius_jets;out["soldier_fx"]=soldier_fx;out["soldier_bolts"]=soldier_bolts;out["cepheus_fx"]=cepheus_fx;out["cepheus_actors"]=cepheus_actors;out["corona_selected"]=corona_selected;out["corona_thrown"]=corona_thrown;out["hound_warning"]=hound_warning;out["aquila_actors"]=aquila_actors;out["aquila_zones"]=aquila_zones;
    out["enemy_weak"]=enemy_weak;out["enemy_health"]=enemy_health;out["petrified_enemies"]=petrified_enemies;out["boss_bodies"]=PhaseController::snapshot(run);out["boss_techniques"]=TechniqueRunner::snapshot(run);out["batches"]=batches;out["shapes"]=shapes;out["poses"]=poses;out["marlin"]=marlin;out["pulser"]=pulser;out["gravity"]=gravity;out["warp"]=warp;out["phoenix"]=phoenix;out["phoenix_fx"]=phoenix_fx;out["phoenix_impacts"]=phoenix_impacts;out["beamer_fx"]=beamer_fx;out["lynx_fx"]=lynx_fx;out["lynx_actors"]=lynx_actors;out["lynx_afterimages"]=lynx_afterimages;out["bite_fx"]=bite_fx;out["cross_actors"]=cross_actors;out["cross_beams"]=cross_beams;out["aquila"]=aquila;out["crows"]=crows;out["comets"]=comets;out["capsules"]=capsules;out["cepheus"]=cepheus;out["triangle_star"]=triangle_star;out["corona"]=corona;out["corona_members"]=corona_members;out["ruler"]=ruler;
    if (run.frame_workspace.metrics.detail_active) {
        const Array bodies=out["boss_bodies"];
        for (const auto &entry:std::initializer_list<std::pair<const char *,int64_t>>{{"rows",int64_t(state.enemies.size())},{"live",live_rows},{"batched",batched_rows},{"bosses",bodies.size()},{"marked",marked_rows}}) {
            auto &sample=run.frame_workspace.metrics.render_rows[entry.first];sample.total_us+=entry.second;++sample.count;sample.max_us=std::max(sample.max_us,entry.second);
        }
    }
    return out;
}
}
