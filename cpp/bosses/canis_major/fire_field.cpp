#include "fire_field.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>

namespace speed {
namespace {
constexpr double pi=3.14159265358979323846;
struct Sample {double x,y,width;int channel;double axial,angle=0;};
uint32_t hash(uint32_t a,uint32_t b) {
    uint32_t h=0x9e3779b9;
    for (uint32_t n:{a,b}) {h=(h^n)*0x85ebca6b;h^=h>>13;h*=0xc2b2ae35;h^=h>>16;}
    return h;
}
double random(int32_t a,int32_t b) {return double(hash(uint32_t(a),uint32_t(b)))/4294967296.0;}
int wrap(int x,int m) {return (x%m+m)%m;}
double noise(double x,int32_t seed,int period=0) {
    const int i=int(std::floor(x));const double f=x-i,u=f*f*(3-2*f);
    const int a=period?wrap(i,period):i,b=period?wrap(i+1,period):i+1;
    return (random(a,seed)+(random(b,seed)-random(a,seed))*u)*2-1;
}
double smooth(double a,double b,double x) {const double t=std::clamp((x-a)/(b-a),0.0,1.0);return t*t*(3-2*t);}
double mod(double x,double n) {return std::fmod(std::fmod(x,n)+n,n);}
}
std::vector<CanisFirePixel> CanisFireField::raster(const CanisFireFieldInput &p) {
    std::vector<CanisFirePixel> out;
    for (double x:{p.world_scale,p.origin_x,p.origin_y,p.angle,p.length,p.width,p.age,p.duration,p.alpha,p.speed_rate,p.spikes}) if (!std::isfinite(x)) return out;
    if (p.alpha<=0 || p.length<4 || p.world_scale<=0 || p.speed_rate<=0 || !p.logical_width || !p.logical_height) return out;
    const double length=p.length*p.world_scale,speed=length/.22*p.speed_rate,front=std::min(length,p.age*speed),back=p.age>p.duration?std::min(length,(p.age-p.duration)*speed):0;
    if (front<=back+1) return out;
    const double w0=std::max(.04,length*.014*p.width);
    const auto flow=[](double t){return 1-.35*std::exp(-std::pow((mod(t,1.6)-.55)/.05,2));};
    const auto center=[&](double x){return noise(p.age*1.2+x*.02,9+p.seed)*2.2*std::pow(x/length,1.5)*w0;};
    const auto width=[&](double x){return (2.1+5*std::pow(x/length,.7))*w0*flow(p.age-x/speed);};
    std::vector<Sample> samples;
    for (double x=back+.2;x<front;x+=.8) {
        const double taper=std::pow(std::clamp((front-x)/std::max(12.0,length*.11),0.0,1.0),1.1);
        const double w=width(x)*(1+.15*noise(x*.4-p.age*15,p.seed+4,24))*smooth(back,back+6,x)*taper;
        if (w<.25) continue;
        const double y=center(x),surge=mod(x*.035-p.age*3,1)<.12?1.15:1;
        const double inner=.66+.08*noise(x*.35-p.age*20,p.seed+12,24),core=.16+.05*noise(x*.4-p.age*26,p.seed+13,24);
        samples.push_back({x,y,w*1.28,0,1.5});samples.push_back({x,y,w*inner*surge*1.28,1,1.5});samples.push_back({x,y,w*core*surge*1.28,2,1.5});
        for (double phase:{0.0,pi}) {const double a=x*.22-p.age*56+phase;if (std::cos(a)>-.1 && w>1.2) {const double sy=y+std::sin(a)*w*.55;samples.push_back({x,sy,1.3,1,1.5});if (std::cos(a)>.55) samples.push_back({x,sy,.9,2,1.5});}}
    }
    if (p.spikes>0) for (int i=0;i<14;++i) {
        const double phase=mod(i*.618+p.age/1.6,1),x=back+8+phase*(front-back-12);
        if (x>front-4) continue;
        const double side=i%2?1:-1,w=width(x),h=(3+12*x/length)*(.55+.6*(.5+.5*noise(p.age*5,i*19+1+p.seed)))*std::min(1.0,(1-phase)*6)*w0/1.5*p.spikes;
        const double bx=-.55,by=side*.8,norm=std::hypot(bx,by);
        for (const auto &layer:std::array<std::array<double,3>,3>{{{{1,1,0}},{{.7,.86,1}},{{.3,.42,2}}}}) {
            const double lw=layer[0],lh=layer[1];
            for (double r=0;r<h*lh;r+=.65) {
                const double u=r/(h*lh),bend=noise(p.age*3,i+p.seed)*.6,offset=bend*u*u*lh+noise(p.age*4+r*.2,p.seed*2+i*19+7)*u*1.1;
                const double xx=x+bx/norm*r-by/norm*offset,yy=center(x)+side*w*.7+by/norm*r+bx/norm*offset;
                if (xx<back || xx>front) continue;
                const double half=(1.1+1.6*x/length)*lw*std::pow(1-u,.85)*std::min(1.0,(r+1.5)/3.5)+noise(p.age*9+r*.45,p.seed*2+i*19)*.5;
                if (half>=.3) samples.push_back({xx,yy,half*1.4,int(layer[2]),1.2,std::atan2(by,bx)});
            }
        }
    }
    if (samples.empty()) return out;
    double min_x=INFINITY,max_x=-INFINITY,side=0;
    for (const auto &q:samples) {const double pad=std::max(q.width,q.axial);min_x=std::min(min_x,q.x-pad);max_x=std::max(max_x,q.x+pad);side=std::max(side,std::abs(q.y)+pad);}
    const int fw=std::max(192,int(std::ceil(side*2+16))),fh=std::max(512,int(std::ceil(max_x+80)));
    const double ox=fw*.5,oy=fh-40;
    std::vector<float> field(size_t(fw)*fh*3,0);
    for (const auto &q:samples) {
        const double cx=ox+q.y,cy=oy-q.x,c=std::cos(q.angle),s=std::sin(q.angle),rx=std::abs(c*q.width)+std::abs(s*q.axial),ry=std::abs(s*q.width)+std::abs(c*q.axial);
        for (int y=std::max(0,int(std::floor(cy-ry)));y<=std::min(fh-1,int(std::ceil(cy+ry)));++y) for (int x=std::max(0,int(std::floor(cx-rx)));x<=std::min(fw-1,int(std::ceil(cx+rx)));++x) {
            const double dx=x+.5-cx,dy=y+.5-cy,u=(dx*c+dy*s)/q.width,v=(-dx*s+dy*c)/q.axial,d2=u*u+v*v;
            if (d2<1) {auto &cell=field[(size_t(y)*fw+x)*3+q.channel];cell=float(cell+std::exp(-d2*3.2)*(1-smooth(.72,1,std::sqrt(d2))));}
        }
    }
    const double c=std::cos(p.angle),s=std::sin(p.angle);
    double lo_x=INFINITY,lo_y=INFINITY,hi_x=-INFINITY,hi_y=-INFINITY;
    for (double x:{min_x,max_x}) for (double y:{-side,side}) {const double wx=p.origin_x+c*x-s*y,wy=p.origin_y+s*x+c*y;lo_x=std::min(lo_x,wx);hi_x=std::max(hi_x,wx);lo_y=std::min(lo_y,wy);hi_y=std::max(hi_y,wy);}
    for (int y=std::max(0,int(std::floor(lo_y)-3));y<=std::min(int(p.logical_height)-1,int(std::ceil(hi_y)+3));++y) for (int x=std::max(0,int(std::floor(lo_x)-3));x<=std::min(int(p.logical_width)-1,int(std::ceil(hi_x)+3));++x) {
        const double dx=x+.5-p.origin_x,dy=y+.5-p.origin_y,wx=std::floor(ox-s*dx+c*dy)+.5,wy=std::floor(oy-c*dx-s*dy)+.5;
        const double u=(std::sin(wy*.075-p.age*4.4)+std::sin(wx*.11+wy*.033+p.age*2.1))*1.2,v=std::cos(wx*.08+p.age*3)*.55*1.2;
        const int xx=int(std::floor(wx+u)),yy=int(std::floor(wy+v));if (xx<0 || xx>=fw || yy<0 || yy>=fh) continue;
        const size_t k=(size_t(yy)*fw+xx)*3;if (field[k]<.34) continue;
        const bool inner=field[k+1]>=.34,core=inner && field[k+2]>=.34;
        out.push_back({x,y,uint8_t(core?2:inner?1:0)});
    }
    return out;
}
}
