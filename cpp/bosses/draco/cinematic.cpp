#include "cinematic.h"
#include <algorithm>
namespace speed {
void DracoCinematic::capture(RunRuntime &r,DracoCinematicState &v) {
    const auto &s=r.state;const auto &c=s.control;v.saved=true;v.controls_locked=s.controls_locked;v.protected_ship=s.encounter_protected;v.camera=c.cinematic_camera;v.hide=c.cinematic_hide_enemies;v.bars=c.cinematic_bars;v.center=s.view_center;v.half=s.view_half;v.zoom=c.camera_zoom;v.world_scale=c.world_scale;v.heading=s.ship.heading;
}
void DracoCinematic::restore(RunRuntime &r,DracoCinematicState &v) {
    if (!v.saved) return;auto &s=r.state;auto &c=s.control;s.controls_locked=v.controls_locked;s.encounter_protected=v.protected_ship;c.cinematic_camera=v.camera;c.cinematic_hide_enemies=v.hide;c.cinematic_bars=v.bars;c.camera_center=s.view_center=v.center;s.view_half=v.half;c.camera_zoom=v.zoom;c.world_scale=v.world_scale;s.ship.heading=v.heading;s.draw.drawing=s.draw.tracing=false;s.ship.vel={};v.saved=false;
}
void DracoCinematic::frame(RunRuntime &r,godot::Vector2 center,double zoom) {
    auto &s=r.state;auto &c=s.control;c.camera_center=s.view_center=center;c.camera_zoom=std::max(0.01,zoom);auto size=c.logical_size;if (size.x<=0 || size.y<=0) size={1280,720};s.view_half=size/(2.0*c.camera_zoom);
}
}
