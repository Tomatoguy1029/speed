#include "render_builder.h"
#include "../bosses/flow/technique_runner.h"
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
    for (size_t i=0;i<instances.size();++i) {
        const auto &v=instances[i];const float c=std::cos(v.angle)*v.radius,s=std::sin(v.angle)*v.radius;
        id[i]=v.id;flag[i]=v.flags;color[i]=v.color;
        t[i*6]=c;t[i*6+1]=s;t[i*6+2]=-s;t[i*6+3]=c;t[i*6+4]=v.at.x;t[i*6+5]=v.at.y;
    }
    Dictionary out;out["visual_id"]=visual;out["layer"]=layer;out["order"]=order;out["ids"]=ids;
    out["transforms"]=transforms;out["colors"]=colors;out["flags"]=flags;
    if (biter) {Dictionary values;values["modes"]=modes;values["charges"]=charges;values["timers"]=timers;values["rests"]=rests;out["biter"]=values;}
    if (!ruler_sides.is_empty()) out["ruler_sides"]=ruler_sides;
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
    for (auto &group:groups) {
        auto &out=group.second;out.instances.clear();out.biter=false;
        out.ruler_sides.clear();out.modes.clear();out.charges.clear();out.timers.clear();out.rests.clear();out.glows.clear();out.gunner.clear();out.beamer.clear();out.missile.clear();out.battleship.clear();out.sniper.clear();out.dolphin.clear();out.lynx.clear();out.soldier.clear();out.reticle.clear();out.aquarius.clear();out.cross.clear();out.bomber.clear();out.crab.clear();out.pump.clear();
    }
    PackedFloat32Array comet_values,crow_values;
    const auto batch=[&](uint32_t visual,int32_t layer,int32_t order)->RenderBatchBuffer & {
        auto &out=groups[visual];out.visual=visual;out.layer=layer;out.order=order;return out;
    };
    for (uint32_t i=0;i<state.field.bodies.size();++i) {
        const auto &body=state.field.bodies[i];
        if (view.grow(body.radius).has_point(body.position)) batch(FieldSystem::visual(run,body),2,0).add(i+1,body.position,0,body.radius,Color(0,0,0,1));
    }
    for (size_t i=0;i<state.enemies.size();++i) {
        const auto &enemy=state.enemies[i];if (!enemy.alive || enemy.dead) continue;
        const auto &definition=run.content->definitions[enemy.definition];if (!definition.visual_id) continue;
        const auto pose=interpolate(previous,{enemy.id,enemy.pos,enemy.facing},i,false,alpha);
        const bool meteor=definition.kind==EnemyDefinition::Kind::Meteor;
        if (meteor && state.field.rock_handles.contains(enemy.rock) && state.field.rocks[enemy.rock.slot].kind==RockKind::Comet) {
            if (view.grow(enemy.radius*1.4142135623730951).has_point(pose.position)) for (float value:{pose.position.x,pose.position.y,float(enemy.radius),enemy.vel.x,enemy.vel.y,float(state.field.rocks[enemy.rock.slot].rare_weapon!=0)}) comet_values.push_back(value);
            continue;
        }
        const double radius=meteor?FieldSystem::rock_sprite_radius(run,uint32_t(i)):enemy.radius*definition.sprite_scale;
        if (!view.grow(radius*1.4142135623730951).has_point(pose.position)) continue;
        auto &enemy_batch=batch(FieldSystem::rock_visual(run,uint32_t(i)),meteor?7:8,int32_t(enemy.definition));
        if (definition.kind==EnemyDefinition::Kind::Crow) {
            const auto cargo=CrowBehavior::cargo(run,state.enemy_handles.at(uint32_t(i)));
            if (cargo.amount>0) for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(cargo.amount),float(cargo.count)}) crow_values.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Biter) {
            enemy_batch.biter=true;enemy_batch.modes.push_back(int32_t(enemy.mode));enemy_batch.charges.push_back(enemy.charge);
            enemy_batch.timers.push_back(enemy.timer);enemy_batch.rests.push_back(definition.bite.rest);
        }
        if ((definition.kind==EnemyDefinition::Kind::Gunner || definition.kind==EnemyDefinition::Kind::Defender) && enemy.charge>0) {
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge)}) enemy_batch.gunner.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Pump) {
            const auto &p=run.content->pumps[definition.pump_definition-1];const double base=definition.radius*(enemy.elite?1.25:1.0);const double full=std::clamp((enemy.radius/std::max(base,0.001)-1.0)/std::max(p.grow,0.001),0.0,1.0);const auto &v=std::get<PumpState>(enemy.behavior_state);
            for (float value:{pose.position.x,pose.position.y,float(pose.angle+definition.sprite_angle),float(base*definition.sprite_scale/18.5),float(enemy.mode==EnemyMode::Windup?1.0:full),float(double(v.contents.size())/p.store_max),float(state.world_time),float(std::min(1.0,enemy.flash*10.0)),enemy.mode==EnemyMode::Move && v.contents.size()<p.store_max?1.0f:0.0f}) enemy_batch.pump.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Crab) {
            const auto &p=run.content->crabs[definition.crab_definition-1];const auto c=definition.color;const auto &v=std::get<CrabState>(enemy.behavior_state);
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle+1.5707963267948966+(v.buds<0?3.141592653589793:0)),float(enemy.mode),float(enemy.charge),float(enemy.timer),float(p.open_time),float(p.reach),c.r,c.g,c.b,c.a,definition.polygon_visual?1.0f:0.0f}) enemy_batch.crab.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Bomber && enemy.mode!=EnemyMode::Windup) {
            for (float v:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(0.7+0.3*std::sin(state.world_time*30.0+double(enemy.id)))}) enemy_batch.bomber.push_back(v);
        }
        if (definition.kind==EnemyDefinition::Kind::Cross && enemy.mode==EnemyMode::Windup) {
            const auto &p=run.content->cross_enemies[definition.cross_definition-1];const auto c=definition.color.lightened(0.2);
            for (float v:{pose.position.x,pose.position.y,float(enemy.radius),float(enemy.charge),float(p.beam_length),c.r,c.g,c.b,c.a}) enemy_batch.cross.push_back(v);
        }
        if (definition.kind==EnemyDefinition::Kind::Aquarius && enemy.charge>0) for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge)}) enemy_batch.aquarius.push_back(value);
        if (definition.kind==EnemyDefinition::Kind::Reticle) {
            const auto &target=std::get<ReticleState>(enemy.behavior_state);const bool valid=enemy.mode==EnemyMode::Windup && state.enemy_handles.contains(target.rock);
            const auto at=valid?state.enemies[target.rock.slot].pos:Vector2();const double radius=valid?state.enemies[target.rock.slot].radius:0;const auto color=definition.color.lightened(0.2);
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge),color.r,color.g,color.b,float(valid),at.x,at.y,float(radius)}) enemy_batch.reticle.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Soldier) {
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.mode),float(enemy.charge),float(0.5+0.5*std::sin(state.world_time*30.0+double(enemy.id)))}) enemy_batch.soldier.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Lynx && enemy.charge>0) {
            const float side=std::get<LynxState>(enemy.behavior_state).buds%2==0?1:-1;
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge),side}) enemy_batch.lynx.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Dolphin && enemy.mode==EnemyMode::Windup) {
            const auto &p=run.content->dolphins[definition.dolphin_definition-1];
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge),float(p.arc)}) enemy_batch.dolphin.push_back(value);
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
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge),float(definition.weak_arc)}) enemy_batch.battleship.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Missile && enemy.charge>0) {
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.charge)}) enemy_batch.missile.push_back(value);
        }
        if (definition.kind==EnemyDefinition::Kind::Beamer) {
            for (float value:{pose.position.x,pose.position.y,float(enemy.radius),float(pose.angle),float(enemy.mode),float(enemy.charge),definition.color.r,definition.color.g,definition.color.b,definition.color.a}) enemy_batch.beamer.push_back(value);
        }
        if (const auto *ruler=std::get_if<RulerState>(&enemy.behavior_state)) enemy_batch.ruler_sides.push_back(ruler->side);
        const bool warning=definition.kind==EnemyDefinition::Kind::Hound && GroupSystem::warning(state,state.enemy_handles.at(uint32_t(i)));
        if (warning) {enemy_batch.glows.push_back(pose.position.x);enemy_batch.glows.push_back(pose.position.y);enemy_batch.glows.push_back(radius);}
        auto color=definition.polygon_visual?(enemy.flash>0?Color(1,1,1,1):definition.color):Color(!meteor && (enemy.flash>0 || warning)?1.0:0.0,0,0,1);
        if (definition.kind==EnemyDefinition::Kind::Bomber && enemy.mode==EnemyMode::Windup) color.g=std::fmod(enemy.charge*3.0,1.0)>=0.45?1.0:0.0;
        enemy_batch.add(enemy.id,pose.position,pose.angle+definition.sprite_angle,radius,color,enemy.flash>0 || warning?1:0);
    }
    for (size_t i=0;i<state.friends.size();++i) {
        const auto &shot=state.friends[i];if (!shot.alive || shot.kind!=int64_t(FriendKind::Shot)) continue;
        const auto pose=interpolate(previous,{shot.id,shot.pos,shot.kind!=int64_t(FriendKind::Shot)?double(shot.angle):double(shot.vel.angle())},i,true,alpha);
        const bool saw=shot.kind==2 && shot.type==StringName("saw");
        const double radius=saw?double(shot.radius):18.0*1.82*config.character_scale;
        if (!view.grow(radius).has_point(pose.position)) continue;
        if (saw && !run.content->rock_fields.empty()) batch(run.content->definitions[run.content->rock_fields.front().saw-1].visual_id,10,0).add(shot.id,pose.position,pose.angle,radius,Color(0,0,0,1));
        else batch(config.shot_visual,10,0).add(shot.id,pose.position,pose.angle,1.82*config.character_scale,Color(1,1,1,1),shot.visual==StringName("weapon/scatter")?(shot.life<0.09?2:1):0);
    }
    for (uint32_t row=0;row<state.hostiles.size();++row) {
        const auto &shot=state.hostiles[row];
        if (shot.alive && shot.star_bolt.definition && view.has_point(shot.pos)) {
            const auto &d=run.content->star_bolts[shot.star_bolt.definition-1];StarBoltSystem::render(run,row,batch(d.visual,10,0),batch(d.stone_visual,10,1));continue;
        }
        if (!shot.alive || !shot.definition || !view.grow(40.0).has_point(shot.pos)) continue;
        const auto &definition=run.content->hostile_definitions[shot.definition-1];const auto *record=AttackSystem::get(state,shot.attack);if (!record) continue;
        batch(definition.visual,10,0).add(record->id,shot.pos,shot.kind==int64_t(HostileKind::Reflected)?shot.vel.angle():0.0,shot.radius,Color(1,1,1,1));
        if (shot.stone>0) batch(definition.stone_visual,10,1).add(record->id,shot.pos,0,shot.radius*1.3,Color(0.62,0.6,0.58,0.9));
    }
    const Color crystal_colors[]={Color::html("08deff"),Color::html("945cff"),Color::html("ffb609")};
    const double pixel=1.82*config.character_scale;
    for (const auto &gem:state.pickups.gems) if (gem.alive && view.grow(60).has_point(gem.pos))
        batch(config.crystal_visual,6,0).add(int64_t(gem.id),gem.pos,0,std::max(5.0,pixel*4.0)*1.4,crystal_colors[gem.kind]);
    for (size_t i=0;i<state.pickups.coins.size();++i) {
        const auto &coin=state.pickups.coins[i];if (coin.alive && view.grow(60).has_point(coin.pos))
            batch(config.coin_visual,6,-1).add(int64_t(i+1),coin.pos,0,std::max(6.0,pixel*3.5),Color::html("ffd24a"));
    }
    PackedFloat64Array pulser;
    for (uint32_t i=0;i<state.enemies.size();++i) {
        const auto &e=state.enemies[i];if (!e.alive || e.dead || e.held || e.stone>0 || state.enemy_handles.contains(e.pump_owner) || e.mode!=EnemyMode::Windup) continue;
        const auto &d=run.content->definitions[e.definition];if (d.kind!=EnemyDefinition::Kind::Pulser) continue;
        const auto &p=run.content->pulsers[d.pulser_definition-1];const double radius=PulserBehavior::ring_radius(run,i);
        if (!view.grow(radius+p.width*26).has_point(e.pos)) continue;
        for (double value:{double(e.pos.x),double(e.pos.y),radius,p.width,1.0-std::clamp(e.timer/std::max(p.warn,0.001),0.0,1.0),double(e.id%4093)}) pulser.push_back(value);
    }
    Dictionary crows;crows["time"]=state.world_time;crows["values"]=crow_values;
    Dictionary comets;comets["time"]=state.time;comets["values"]=comet_values;
    Dictionary capsules;PackedFloat32Array capsule_values;for (const auto &cap:state.pickups.capsules) for (float value:{cap.pos.x,cap.pos.y,float(cap.kind)}) capsule_values.push_back(value);capsules["time"]=state.time;capsules["values"]=capsule_values;
    Dictionary warp;warp["position"]=state.field.warp_pos;warp["gone"]=state.field.warp_gone;warp["radius"]=run.content->warp.radius;warp["time"]=state.world_time;
    Dictionary gravity;PackedFloat64Array well_values;
    for (const auto &well:state.field.wells) for (double value:{double(well.position.x),double(well.position.y),well.born,well.life,well.radius}) well_values.push_back(value);
    gravity["time"]=state.world_time;gravity["wells"]=well_values;
    PackedFloat64Array ruler;
    for (const auto &e:state.enemies) if (e.alive && !e.dead && std::holds_alternative<RulerState>(e.behavior_state)) {
        const auto &d=run.content->definitions[e.definition];const auto &p=run.content->rulers[d.ruler_definition-1];const auto color=d.color.lightened(0.2);
        for (double value:{double(e.pos.x),double(e.pos.y),e.radius,e.facing,double(e.mode),e.charge,p.beam_len,p.beam_width,p.beam_start_gap,double(color.r),double(color.g),double(color.b)}) ruler.push_back(value);
    }
    PackedFloat64Array triangle_star;
    for (const auto &h:state.hazards) {const auto *w=std::get_if<WallHazard>(&h.shape);const auto *record=AttackSystem::get(state,h.attack);
        if (!h.alive || !w || w->style!=uint32_t(WallStyle::Trail) || !record || !state.enemy_handles.contains(record->spec.owner.live_source)) continue;
        const auto &owner=state.enemies[record->spec.owner.live_source.slot];if (owner.dead || run.content->definitions[owner.definition].kind!=EnemyDefinition::Kind::TriangleStar) continue;
        const auto head=h.pos+Vector2::from_angle(w->angle)*w->length;for (double value:{double(h.pos.x),double(h.pos.y),double(head.x),double(head.y),double(w->half_width)*2}) triangle_star.push_back(value);
    }
    Dictionary cepheus;PackedFloat64Array cepheus_values,cepheus_marks;
    for (const auto &e:state.enemies) if (e.alive && !e.dead && std::holds_alternative<CepheusState>(e.behavior_state) && e.mode==EnemyMode::Windup) for (double v:{double(e.pos.x),double(e.pos.y),e.radius,e.facing,e.charge}) cepheus_values.push_back(v);
    for (const auto &m:state.groups.summon_marks) {const double age=m.age;if (age>=m.life) continue;for (double v:{double(m.pos.x),double(m.pos.y),double(m.king.x),double(m.king.y),double(m.color.r),double(m.color.g),double(m.color.b),double(m.color.a),age/m.life,state.world_time}) cepheus_marks.push_back(v);}
    cepheus["values"]=cepheus_values;cepheus["marks"]=cepheus_marks;
    PackedFloat64Array corona,corona_members;
    for (const auto &e:state.enemies) {
        if (!e.alive || e.dead) continue;
        if (const auto *o=std::get_if<CoronaState>(&e.behavior_state)) if (o->ready && view.grow(200).has_point(e.pos)) {const auto &p=run.content->coronas[run.content->definitions[e.definition].corona_definition-1];for (double v:{double(e.pos.x),double(e.pos.y),p.ring,state.world_time*p.spin,e.radius,double(e.mode),e.charge}) corona.push_back(v);}
        if (e.corona && view.grow(180).has_point(e.pos) && state.enemy_handles.contains(e.corona->owner)) {const auto &a=*e.corona;const auto &owner=state.enemies[a.owner.slot];const auto &o=std::get<CoronaState>(owner.behavior_state);const bool selected=state.enemy_handles.contains(o.selected) && state.enemy_handles.entity_id(o.selected)==e.id;for (double v:{double(e.pos.x),double(e.pos.y),e.radius*a.effect,a.thrown?1.0:0.0,double(e.vel.x),double(e.vel.y),selected?1.0:0.0,double(owner.pos.x),double(owner.pos.y),state.world_time}) corona_members.push_back(v);}
    }
    Dictionary aquila;PackedFloat64Array aquila_values;
    for (const auto &e:state.enemies) {
        if (!e.alive || e.dead || e.mode!=EnemyMode::Windup) continue;const auto &d=run.content->definitions[e.definition];if (d.kind!=EnemyDefinition::Kind::Aquila) continue;
        const auto &p=run.content->aquilas[d.aquila_definition-1];const auto center=std::get<AquilaState>(e.behavior_state).anchor;
        for (double v:{double(e.pos.x),double(e.pos.y),e.radius,e.charge,double(center.x),double(center.y),p.dash_speed*p.drop_step,p.blast_radius,e.held || e.stone>0?0.0:1.0}) aquila_values.push_back(v);
    }
    aquila["values"]=aquila_values;aquila["view"]=view;
    PackedFloat64Array phoenix;
    for (const auto &e:state.enemies) {
        if (!e.alive || e.dead || (e.mode!=EnemyMode::Windup && e.mode!=EnemyMode::Dash)) continue;const auto &d=run.content->definitions[e.definition];if (d.kind!=EnemyDefinition::Kind::Phoenix) continue;
        const auto &p=run.content->phoenixes[d.phoenix_definition-1];const auto center=std::get<PhoenixState>(e.behavior_state).anchor;const double radius=std::max(e.radius*1.1,p.impact_radius);
        if (!view.grow(radius*3).has_point(center)) continue;
        for (double v:{double(center.x),double(center.y),e.radius,e.facing,radius,e.mode==EnemyMode::Windup?e.charge:1.0,double(e.id%31)/31.0}) phoenix.push_back(v);
    }
    Dictionary marlin;PackedInt64Array marlin_ids;PackedFloat64Array marlin_values;
    for (size_t i=0;i<state.enemies.size();++i) {
        const auto &e=state.enemies[i];if (!e.alive || e.dead || e.held || e.stone>0) continue;const auto &d=run.content->definitions[e.definition];if (d.kind!=EnemyDefinition::Kind::Marlin) continue;
        const auto &p=run.content->marlins[d.marlin_definition-1];const auto direction=Vector2::from_angle(e.facing),from=e.pos+direction*e.radius;auto to=e.pos+direction*p.dash_speed*p.dash_time;
        if (const auto hit=FieldSystem::first_body_hit(run,e.pos,to,e.radius)) to=e.pos.lerp(to,hit->t);
        marlin_ids.push_back(e.id);for (double v:{double(e.pos.x),double(e.pos.y),e.facing,e.radius,e.radius*d.sprite_scale,d.sprite_angle+e.facing,double(e.mode),e.charge,e.timer,p.dash_time,double(from.x),double(from.y),double(to.x),double(to.y)}) marlin_values.push_back(v);
    }
    marlin["ids"]=marlin_ids;marlin["values"]=marlin_values;marlin["view"]=view;
    Array batches;for (auto &group:groups) if (!group.second.instances.empty()) batches.push_back(group.second.value());
    Array shapes;
    for (uint32_t row=0;row<state.friends.size();++row) {FriendDebrisSystem::render(run,row,view,shapes,alpha);FriendHullSystem::render(run,row,view,shapes,alpha);}
    for (uint32_t row=0;row<state.hazards.size();++row) {BeamSystem::render(run,row,view,shapes);WaveSystem::render(run,row,view,shapes);WallSystem::render(run,row,view,shapes);BlastSystem::render(run,row,view,shapes);ZoneSystem::render(run,row,view,shapes);FloodSystem::render(run,row,view,shapes);}
    for (uint32_t row=0;row<state.hostiles.size();++row) {SlashSystem::render(run,row,view,shapes);BoltSystem::render(run,row,view,shapes);LightArrowSystem::render(run,row,view,shapes);ShellSystem::render(run,row,view,shapes);}
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
    const double forward_recoil=state.forward.recoil>0?(state.forward.recoil>0.06?2.0:1.0)*pixel:0;
    const auto &scatter=state.loadout.scatter;
    const double scatter_recoil=scatter.recoil>0?(scatter.recoil>0.035?2.0:1.0)*pixel:0;
    const auto at=ship-state.ship.heading*std::max(forward_recoil,scatter_recoil);
    const Transform2D transform(angle+godot::Math::PI/2.0,Vector2(config.character_scale,config.character_scale),0,at);
    int32_t visual_state=state.ship.hurt>0?1:0;
    if (state.ship.invuln>0 && std::fmod(state.time*20.0,2.0)<1.0) visual_state|=2;
    for (const auto visual:{config.cannon_visual,config.ship_visual}) {
        Dictionary pose;pose["participant_id"]=0;pose["part_key"]=visual;pose["transform"]=transform;
        pose["visible"]=state.phase!=godot::RunState::Phase::Ended && !(state.phase==godot::RunState::Phase::Dying && state.sequence_t>=state.death_freeze) && (visual!=config.cannon_visual || state.forward.ready || scatter.ready);pose["visual_state"]=visual_state;poses.push_back(pose);
    }
    Dictionary out;out["schema_version"]=1;out["epoch"]=run.epoch;out["tick"]=state.control.tick;
    out["boss_techniques"]=TechniqueRunner::snapshot(run);out["batches"]=batches;out["shapes"]=shapes;out["poses"]=poses;out["marlin"]=marlin;out["pulser"]=pulser;out["gravity"]=gravity;out["warp"]=warp;out["phoenix"]=phoenix;out["aquila"]=aquila;out["crows"]=crows;out["comets"]=comets;out["capsules"]=capsules;out["cepheus"]=cepheus;out["triangle_star"]=triangle_star;out["corona"]=corona;out["corona_members"]=corona_members;out["ruler"]=ruler;return out;
}
}
