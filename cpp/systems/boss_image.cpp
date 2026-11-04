#include "boss_image.h"
#include "../runtime/run_runtime.h"
#include <cmath>
namespace speed {
namespace {
const BossBodyState *body_for(const RunRuntime &r,EnemyHandle actor) {
    for (const auto &body:r.state.bosses.bodies)
        if (body.actor.slot==actor.slot && body.actor.generation==actor.generation) return &body;
    return nullptr;
}
bool solid(const ContentBundle &content,const BossBodyState &body,godot::Vector2 point) {
    for (const auto &part:body.image_parts) {
        if (!part.visible || !part.mask || part.mask>content.boss_image_masks.size() || std::abs(part.pixel_to_world.determinant())<1e-12) continue;
        const auto local=part.pixel_to_world.affine_inverse().xform(point);
        const int x=int(std::floor(local.x)),y=int(std::floor(local.y));
        if (x<0 || y<0 || x>=part.region.size.x || y>=part.region.size.y) continue;
        const auto &mask=content.boss_image_masks[part.mask-1];
        const int sx=x+part.region.position.x,sy=y+part.region.position.y;
        if (sx<0 || sy<0 || sx>=int(mask.width) || sy>=int(mask.height)) continue;
        const uint64_t index=uint64_t(sy)*mask.width+sx;
        if (index/8<mask.bits.size() && (mask.bits[index/8] & (1u<<(index%8)))) return true;
    }
    return false;
}
}
bool BossImageSystem::available(const RunRuntime &r,EnemyHandle actor) {
    const auto *body=body_for(r,actor);return body && !body->image_parts.empty();
}
bool BossImageSystem::cut(const RunRuntime &r,EnemyHandle actor,godot::Vector2 from,godot::Vector2 direction,BossImageCut &result) {
    if (!r.state.enemy_handles.contains(actor) || !from.is_finite() || !direction.is_finite() || direction.length_squared()<1e-12) return false;
    const auto *body=body_for(r,actor);if (!body || body->image_parts.empty()) return false;
    const auto &enemy=r.state.enemies[actor.slot];
    const double radius=enemy.radius*2.0,limit=(from.distance_to(enemy.pos)+radius)*2.0;
    const int size=int(std::ceil(radius*2.0));
    direction=direction.normalized();bool found=false;
    for (double distance=0;distance<=limit;distance+=1.0) {
        const auto point=from+direction*distance;
        const auto relative=point-enemy.pos+godot::Vector2(radius,radius);
        const int x=int(std::floor(relative.x)),y=int(std::floor(relative.y));
        if (x<0 || y<0 || x>=size || y>=size) continue;
        // cenCut と同じ、ワールド1画素のcanvasへ描いた画素中心を参照する。
        const auto sample=enemy.pos-godot::Vector2(radius,radius)+godot::Vector2(x+0.5,y+0.5);
        if (solid(*r.content,*body,sample)) {if (!found) result.enter=point;result.exit=point;found=true;}
    }
    return found;
}
}
