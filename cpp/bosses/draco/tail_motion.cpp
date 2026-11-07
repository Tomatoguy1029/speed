#include "tail_motion.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double PI=3.141592653589793;
double unit(double x) {return std::clamp(x,0.0,1.0);}
double blend(double a,double b,double k) {return a+(b-a)*k;}
double wrap(double a) {return std::remainder(a,PI*2);}
double wind_q(double x,double u) {return unit((unit(x)-0.36*u)/0.64);}
double wind_hit(double x,double u) {const double q=wind_q(x,u);return blend(DracoTailMotion::smooth(0,1,q),q*q,u);}
double sweep_turn(const DracoTailTiming &r,double t,double u) {if (t<r.warn) return -DracoTailMotion::wind(t/r.warn,u);t-=r.warn;if (t<r.active) return -1+2*DracoTailMotion::wind(t/r.active,u);return 1-DracoTailMotion::wind(std::pow(unit((t-r.active)/r.recover),1.7),u);}
double bump(double x) {const double v=std::sin(PI*unit(x));return v*v;}
double sweep_flick(const DracoTailTiming &r,double t) {if (t<r.warn) return -0.5*bump(t/r.warn);const double s=(t-r.warn)/r.active,after=std::max(0.0,t-r.warn-r.active);return -0.9*bump(s/0.6)+1.2*bump((s-0.35)/1.3)+0.3*std::sin(after*4.2)*std::exp(-after*1.5)*DracoTailMotion::smooth(0,0.3,after);}
double sweep_shape(double w,double u) {return w<0?w*(-0.35+2.1*u):w*3*std::pow(u,1.15);}
double slam_shape(double w,double u) {return w>=0?sweep_shape(w,u):-w*(-0.7+u-1.1*DracoTailMotion::smooth(0.78,1,u));}
double slam_turn(const DracoTailTiming &r,double t,double u) {const double strike=DracoTailMotion::strike_time(r);if (t<r.warn) return DracoTailMotion::wind(t/r.warn,u);t-=r.warn;if (t<strike) return 1-2*wind_hit(t/strike,u);if (t<r.active) return -1;return -1+DracoTailMotion::wind(std::pow(unit((t-r.active)/r.recover),1.7),u);}
// 振り下ろしはどの節も同じ向きへ少しずつ移す。根元を先に回しすぎると尾が一度逆へ振れる。
double slam_strike(double x,double u) {const double q=unit((unit(x)-0.14*u)/0.86);return blend(DracoTailMotion::smooth(0,1,q),q*q,u);}
double slam_bend(const DracoTailTiming &r,double t,double u) {const double strike=DracoTailMotion::strike_time(r),d=t-r.warn;return d>=0 && d<strike?blend(slam_shape(1,u),slam_shape(-1,u),slam_strike(d/strike,u)):slam_shape(slam_turn(r,t,u),u);}
}
double DracoTailMotion::soft(double q) {return q*q*q*(q*(q*6-15)+10);}
double DracoTailMotion::smooth(double a,double b,double x) {const double t=unit((x-a)/(b-a));return t*t*(3-2*t);}
// 根元はポーズAからBへ先に動き終え、先端は遅れて追いつき、行き過ぎてから戻る。
double DracoTailMotion::wind(double x,double u) {const double q=wind_q(x,u),o=q-1;return blend(soft(q),1+1.7*o*o*o+0.7*o*o,0.5*u*u);}
std::vector<godot::Vector2> DracoTailMotion::wave(const std::vector<godot::Vector2> &base,double axis,godot::Vector2 head,double length,double flat,const std::function<double(double)> &turn) {
    const size_t count=base.size()-1;const double straight=axis+PI,segment=length/count;std::vector<double> angles(count),bend(count);
    for (size_t j=0;j<count;++j) {const double a=(base[j+1]-base[j]).angle();angles[j]=a+wrap(straight-a)*flat;bend[j]=turn(double(j)/std::max(size_t(1),count-1));}
    for (int pass=0;pass<8;++pass) {auto next=bend;for (size_t j=1;j+1<count;++j) next[j]=(bend[j-1]+2*bend[j]+bend[j+1])/4;bend=std::move(next);}
    std::vector<godot::Vector2> points{head};auto at=head;for (size_t j=0;j<count;++j) {at+=godot::Vector2::from_angle(angles[j]+bend[j])*segment;points.push_back(at);}return points;
}
std::vector<godot::Vector2> DracoTailMotion::sweep(const std::vector<godot::Vector2> &base,double axis,godot::Vector2 origin,double length,const DracoTailTiming &r,double clock,double *facing) {
    const auto side=godot::Vector2::from_angle(axis).orthogonal()*-1;const double flick=sweep_flick(r,clock),flat=smooth(0,0.4,std::abs(sweep_turn(r,clock,0.3)));
    const auto turn=[&](double u) {const double w=smooth(0.5,1,u);return sweep_shape(sweep_turn(r,clock,u),u)+flick*w*w;};
    if (facing) *facing=axis+turn(0);return wave(base,axis,origin+side*(-sweep_turn(r,clock,0)*90),length,flat,turn);
}
std::vector<godot::Vector2> DracoTailMotion::slam(const std::vector<godot::Vector2> &base,double axis,godot::Vector2 origin,double length,double mirror,const DracoTailTiming &r,double clock,double *facing) {
    const auto side=godot::Vector2::from_angle(axis).orthogonal()*-1;const double strike=strike_time(r),d=clock-r.warn,w=d>=0 && d<strike?1-2*slam_strike(d/strike,0):slam_turn(r,clock,0),flat=smooth(0,0.4,std::abs(slam_turn(r,std::min(clock,r.warn),0.3)));
    const auto turn=[&](double u) {return mirror*slam_bend(r,clock,u);};
    if (facing) *facing=axis+turn(0);return wave(base,axis,origin+side*(-mirror*w*90),length,flat,turn);
}
}
