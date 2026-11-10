#include "fuel.h"
#include "../runtime/run_runtime.h"
#include "../state/loadout_state.h"
#include "../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
bool FuelSystem::valid(const godot::RunState &s) {
    const auto &c=s.draw_config;
    for (double v:{c.fuel_capacity,c.cruise_drain,c.regen_rate,c.fuel_low,c.fuel_speed_min,c.fuel_slow_time,c.boost_cost_ratio,c.boost_min_cost,c.boost_min_q,c.fuel_hole_ratio,c.fuel_gain_max,c.fuel_notify_reset})
        if (!std::isfinite(v) || v<0) return false;
    return c.fuel_capacity>0 && c.fuel_low>0 && c.fuel_slow_time>0 && c.cruise_drain>0 && c.fuel_speed_min<1 &&
        c.boost_cost_ratio>0 && c.boost_cost_ratio<=1 && c.boost_min_q>0 && c.boost_min_q<=1 &&
        c.fuel_hole_ratio>0 && c.fuel_hole_ratio<=1 && c.fuel_notify_reset>0 && c.fuel_notify_reset<=1;
}
double FuelSystem::maximum(const godot::RunState &s) {return s.draw_config.fuel_capacity*s.draw_config.capacity;}
double FuelSystem::amount(const godot::RunState &s) {return std::max(s.draw.fuel/s.draw_config.fuel_capacity,s.draw_config.boost_min_q);}
double FuelSystem::draw_limit(const godot::RunState &s) {
    const auto &c=s.draw_config;
    return c.length*(s.draw.fuel/c.fuel_capacity)*(s.ship_config.max_speed/s.ship_config.base_max_speed)*c.length_mult/c.boost_cost_ratio;
}
double FuelSystem::draw_cost(const godot::RunState &s) {
    const auto &d=s.draw;const auto &c=s.draw_config;
    if (d.points.is_empty() || d.limit<=0 || s.control.bonus_remaining>0) return 0;
    const double used=d.connection+d.length;
    const bool at_limit=!d.blocked && d.limit-used<c.point_step;
    const double fraction=at_limit?1.0:std::min(1.0,used/d.limit);
    return std::max(c.boost_min_cost,d.start_fuel*fraction);
}
double FuelSystem::speed_ratio(const godot::RunState &s) {
    if (!s.draw_ready) return 1.0;
    const auto &c=s.draw_config;
    return c.fuel_speed_min+(1-c.fuel_speed_min)*std::clamp(s.draw.fuel/c.fuel_low,0.0,1.0);
}
void FuelSystem::set(RunRuntime &r,double fuel,bool silent) {
    auto &s=r.state;auto &d=s.draw;const auto &c=s.draw_config;const double max=maximum(s);
    const bool bonus=s.control.bonus_remaining>0;
    d.fuel=bonus?max:std::clamp(fuel,0.0,max);
    if (silent || bonus) {d.full_notified=d.burst_notified=true;return;}
    if (d.fuel<max*c.fuel_notify_reset) d.full_notified=false;
    if (d.fuel<c.fuel_capacity*c.fuel_notify_reset) d.burst_notified=false;
    if (d.fuel>=max && !d.full_notified) {d.full_notified=true;FrameBuilder::append(r,"gauge_full",{});}
    if (d.fuel>=c.fuel_capacity && !d.burst_notified) {
        d.burst_notified=true;
        if (s.loadout->full_burst_owned) {godot::Dictionary event;event["pos"]=s.ship.pos;FrameBuilder::append(r,"full_burst_ready",event);}
    }
}
void FuelSystem::add(RunRuntime &r,double fuel,bool multiplier) {
    set(r,r.state.draw.fuel+fuel*(multiplier?r.state.draw_config.fuel_gain_mult:1.0));
}
void FuelSystem::step(RunRuntime &r,double dt,bool flying) {
    auto &s=r.state;const auto &c=s.draw_config;
    if (s.control.bonus_remaining>0) {set(r,maximum(s),true);return;}
    if (dt<=0 || s.draw.drawing || s.draw.tracing) return;
    const double drain=flying?c.cruise_drain*c.drain_mult*speed_ratio(s):0;
    set(r,s.draw.fuel+(c.regen_rate*c.regen_mult-drain)*dt);
}
}
