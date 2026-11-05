#include "boss_image.h"
#include "../runtime/run_runtime.h"
#include "../bosses/centaurus/image_pose_system.h"
#include "../bosses/centaurus/reference_fx.h"
#include "../bosses/canis_major/image_pose.h"
#include "../bosses/canis_major/roar.h"
#include "../bosses/monoceros/image_pose_system.h"
#include "../state/boss_states.h"
#include "../content/content_bundle.h"
#include <cmath>
#include <algorithm>
namespace speed {
namespace {
const BossBodyState *body_for(const RunRuntime &r,EnemyHandle actor) {
    for (const auto &body:r.state.bosses->bodies)
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
void BossImageSystem::refresh(RunRuntime &r) {
    for (auto &body:r.state.bosses->bodies) {
        if (!r.state.enemy_handles.contains(body.actor) || r.state.enemies[body.actor.slot].dead) {body.image_parts.clear();continue;}
        if (!body.definition || body.definition>r.content->boss_bodies.size()) continue;
        const auto boss=r.content->boss_bodies[body.definition-1].boss;
        if (!boss || boss>r.content->bosses.size()) continue;
        switch (r.content->bosses[boss-1].kind) {
        case 0:MonocerosImagePoseSystem::refresh(r,body);break;
        case 1:CentaurusImagePoseSystem::refresh(r,body);CentaurusReferenceFx::update(r,body);break;
        case 2:CanisRoar::update(r,body);CanisImagePose::update(r,body);break;
        default:break;
        }
    }
}
bool BossImageSystem::available(const RunRuntime &r,EnemyHandle actor) {
    const auto *body=body_for(r,actor);return body && !body->image_parts.empty();
}
bool BossImageSystem::cut(const RunRuntime &r,EnemyHandle actor,godot::Vector2 from,godot::Vector2 direction,BossImageCut &result,double max_entry) {
    if (!r.state.enemy_handles.contains(actor) || !from.is_finite() || !direction.is_finite() || direction.length_squared()<1e-12) return false;
    const auto *body=body_for(r,actor);if (!body || body->image_parts.empty()) return false;
    const auto &enemy=r.state.enemies[actor.slot];
    const double radius=enemy.radius*2.0,limit=(from.distance_to(enemy.pos)+radius)*2.0;
    const int size=int(std::ceil(radius*2.0));
    direction=direction.normalized();bool found=false,has_bounds=false;
    godot::Vector2 low,high;
    for (const auto &part:body->image_parts) if (part.visible) {
        for (const auto corner:{godot::Vector2(),godot::Vector2(part.region.size.x,0),godot::Vector2(0,part.region.size.y),godot::Vector2(part.region.size)}) {
            const auto point=part.pixel_to_world.xform(corner);
            if (!has_bounds) {low=high=point;has_bounds=true;} else {low=low.min(point);high=high.max(point);}
        }
    }
    if (!has_bounds) return false;
    // 1画素の参照点への丸めを含める。走査の整数位相はfrom基準のまま保つ。
    low-=godot::Vector2(1,1);high+=godot::Vector2(1,1);
    double first=0,last=limit;
    for (int axis=0;axis<2;++axis) {
        if (std::abs(direction[axis])<1e-12) {if (from[axis]<low[axis] || from[axis]>high[axis]) return false;continue;}
        double a=(low[axis]-from[axis])/direction[axis],b=(high[axis]-from[axis])/direction[axis];
        if (a>b) std::swap(a,b);first=std::max(first,a);last=std::min(last,b);
    }
    if (first>last || (max_entry>=0 && first>max_entry)) return false;
    for (double distance=std::ceil(first);distance<=last;distance+=1.0) {
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
