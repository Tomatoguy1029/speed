#include "run_runner.h"
#include "../api/run_core.h"
#include <algorithm>
#include <cmath>
namespace speed {
void RunRunner::camera(godot::SpeedRunCore &core,double dt,godot::Vector2 size) {
    auto &state=core.runtime.state;auto &control=state.control;
    const double factor=std::pow(control.zoom_ref_speed/std::max(control.zoom_ref_speed,state.ship_config.max_speed),control.zoom_exp);
    const double zoom=std::min(size.x,size.y)/control.base_view*std::clamp(factor,control.zoom_min,1.0);
    if (!control.camera_ready) {control.camera_center=state.ship.pos;control.camera_zoom=zoom;control.camera_ready=true;}
    if (!state.draw.drawing && !state.draw.tracing) {
        auto offset=state.ship.vel*control.look_ahead;
        const double maximum=0.3*std::min(size.x,size.y)/2.0/zoom;
        if (offset.length()>maximum) offset=offset.normalized()*maximum;
        control.camera_center+=(state.ship.pos+offset-control.camera_center)*(1.0-std::exp(-7.0*dt));
        control.camera_zoom+=(zoom-control.camera_zoom)*(1.0-std::exp(-2.2*dt));
    }
    control.logical_size=size;
    state.view_center=control.camera_center;state.view_half=size/2.0/control.camera_zoom;
}
bool RunRunner::step_play(godot::SpeedRunCore &core,double dt,const InputFrame &input,godot::Vector2 size) {
    auto &state=core.runtime.state;
    state.control.last_input=input;
    if (state.phase==godot::RunState::Phase::Paused) return true;
    if (state.phase!=godot::RunState::Phase::Play) return false;
    camera(core,0,size);
    state.sim_time+=dt;
    if (!core.handle_draw_input(input,int64_t(std::round(state.sim_time*1000)),state.control.camera_zoom) || !core.step_draw(dt)) return false;
    const double world_dt=dt*core.world_scale();
    state.time+=dt;state.world_time+=world_dt;
    core.advance_enemies(world_dt);
    if (!core.step_ship_input(dt,world_dt,input)) return false;
    state.ship_pos=state.ship.pos;
    camera(core,dt,size);
    return true;
}
}
