#include "lump.h"
#include "bullet.h"
#include "../attack_system.h"
#include "../../output/frame_builder.h"
#include "../../content/content_bundle.h"
#include <cmath>
namespace speed {
AttackHandle LumpSystem::emit(RunRuntime &run,const LumpParams &p) {
    if (!run.state.started || run.state.closed || !run.state.enemy_handles.contains(p.source) || run.content->lumps.empty() || !std::isfinite(p.angle)) return {};
    for (double v:{p.speed,p.radius}) if (!std::isfinite(float(v)) || v<0) return {};
    if (!std::isfinite(p.damage) || p.damage<0) return {};
    const auto source=run.state.enemies[p.source.slot];const auto u=godot::Vector2::from_angle(p.angle);const auto &d=run.content->lumps.front();
    BulletSpawn bullet;bullet.source=p.source;bullet.definition=d.projectile;bullet.position=source.pos+u*(source.radius+p.radius);bullet.velocity=u*p.speed;
    bullet.speed=p.speed;bullet.radius=p.radius;bullet.life=d.life;bullet.damage=p.damage;bullet.budget=p.budget;
    const auto handle=BulletSystem::emit(run,bullet);
    if (AttackSystem::get(run.state,handle)) {godot::Dictionary event;event["pos"]=source.pos;event["kind"]=godot::StringName("lump");FrameBuilder::append(run,"shoot",event);}
    return handle;
}
}
