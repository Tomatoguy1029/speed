#include "fx_raster.h"
#include <algorithm>
#include <cmath>
#include <initializer_list>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
namespace godot {
namespace {
constexpr double PI=3.141592653589793,TAU=PI*2;
double clamp1(double v) {return std::clamp(v,0.0,1.0);}
double smooth(double a,double b,double x) {const double t=clamp1((x-a)/(b-a));return t*t*(3-2*t);}
double mix1(double a,double b,double k) {return a+(b-a)*k;}
double wrap(double a) {return std::remainder(a,TAU);}
double hash1(double n) {const double v=std::sin(n*127.1+311.7)*43758.5453;return v-std::floor(v);}
double noise1(double x,double seed) {const double i=std::floor(x),f=x-i;return mix1(hash1(i*1.37+seed*7.1),hash1((i+1)*1.37+seed*7.1),f*f*(3-2*f))*2-1;}
double N(double time,double rate,double seed,double offset=0) {return noise1(time*rate+offset,seed);}
double noise2(double x,double y,double seed) {const double i=std::floor(x),j=std::floor(y),f=x-i,g=y-j,u=f*f*(3-2*f),v=g*g*(3-2*g);const auto at=[&](double a,double b) {return hash1(a*1.37+b*57.3+seed*7.1);};return mix1(mix1(at(i,j),at(i+1,j),u),mix1(at(i,j+1),at(i+1,j+1),u),v)*2-1;}
double fbm(double x,double y,double seed,int octaves) {double sum=0,amp=0.5,total=0;for (int k=0;k<octaves;++k) {sum+=amp*noise2(x,y,seed+k*3.1);total+=amp;x*=2;y*=2;amp*=0.5;}return sum/total;}
// Aquarius の整数ハッシュと乱数。Corona の粒の発生順を同じまま扱う。
uint32_t reference_hash(std::initializer_list<int64_t> values) {
    uint32_t h=0x9e3779b9;
    for (int64_t n:values) {h=(h^uint32_t(n))*0x85ebca6b;h^=h>>13;h*=0xc2b2ae35;h^=h>>16;}
    return h;
}
struct ReferenceRng {
    uint32_t state;
    explicit ReferenceRng(uint32_t seed):state(seed?seed:1) {}
    double next() {
        state+=0x6d2b79f5;
        uint32_t t=(state^(state>>15))*(state|1);
        t^=t+((t^(t>>7))*(t|61));
        return double(t^(t>>14))/4294967296.0;
    }
    double between(double a,double b) {return mix1(a,b,next());}
};
Color hexc(uint32_t v) {return Color(((v>>16)&255)/255.0f,((v>>8)&255)/255.0f,(v&255)/255.0f);}
const Color FLAME[9]={hexc(0xffffff),hexc(0xfbf4ff),hexc(0xe6d8ff),hexc(0xc9b0ff),hexc(0xa884ff),hexc(0x8259ee),hexc(0x5f3cc8),hexc(0x412a94),hexc(0x291c62)};
const Color DARK[8]={hexc(0xf4e2ff),hexc(0xd39bff),hexc(0x9a4cf0),hexc(0x6a24c4),hexc(0x3e1484),hexc(0x220b50),hexc(0x110630),hexc(0x070214)};
const Color WIND[8]={hexc(0x0b1f1a),hexc(0x123d2c),hexc(0x1d6b45),hexc(0x2fa35e),hexc(0x5fd27a),hexc(0xa6f0a0),hexc(0xdcffd6),hexc(0xffffff)};
const Color PINK=hexc(0xff5fd2),CYAN=hexc(0x58d8ff),VIOLET=hexc(0x8a5cff);
const double LAYERS[4][3]={{1,1,6},{0.76,0.86,4},{0.54,0.68,2},{0.3,0.42,0}};
const double BACK_LAYERS[4][3]={{1,1,7},{0.76,0.86,5},{0.54,0.68,3},{0.3,0.42,2}};
const double COOL_LAYERS[3][3]={{1,1,7},{0.72,0.82,6},{0.44,0.58,5}};
Color cmix(Color a,Color b,double k) {return a.lerp(b,float(k));}
// fxlib.js の FX.ramp：主色から暗→明の5段。
struct Ramp {Color v[5];explicit Ramp(Color c) {const auto mk=[&](double l,double w) {return Color(float(std::min(1.0,c.r*l+w*(1-c.r*l))),float(std::min(1.0,c.g*l+w*(1-c.g*l))),float(std::min(1.0,c.b*l+w*(1-c.b*l))));};v[0]=mk(0.35,0);v[1]=mk(0.6,0);v[2]=mk(1,0);v[3]=mk(1,0.45);v[4]=Color(1,1,1);}};
}
void SpeedFxRaster::_bind_methods() {
    ClassDB::bind_method(D_METHOD("aquila_cracks","paths","center","heat","colors","fade"),&SpeedFxRaster::aquila_cracks);
    ClassDB::bind_method(D_METHOD("aquila_wake","history","clock","strength","colors","fade","light_strength"),&SpeedFxRaster::aquila_wake);
    ClassDB::bind_method(D_METHOD("phoenix_stamp_scorch","field","size","radius","particles"),&SpeedFxRaster::phoenix_stamp_scorch);
    ClassDB::bind_method(D_METHOD("phoenix_scorch","field","size","radius","age","palette","settings"),&SpeedFxRaster::phoenix_scorch);
    ClassDB::bind_method(D_METHOD("lightning_ink","paths","strength","colors","scale","thin","glow_strength","fade","light_strength"),&SpeedFxRaster::lightning_ink);
    ClassDB::bind_method(D_METHOD("canvas_glow_line","a","b","radius","color","strength","fade","light_strength"),&SpeedFxRaster::canvas_glow_line);
    ClassDB::bind_method(D_METHOD("canvas_glow_ring","center","radius","width","color","strength","fade","light_strength"),&SpeedFxRaster::canvas_glow_ring);
    ClassDB::bind_method(D_METHOD("canvas_circle","x","y","radius","color","alpha","fade","blended"),&SpeedFxRaster::canvas_circle);
    ClassDB::bind_method(D_METHOD("canvas_beam","x0","y0","x1","y1","width","color","alpha","fade"),&SpeedFxRaster::canvas_beam);
    ClassDB::bind_method(D_METHOD("canvas_flame_blade","shape","palette","layers","fade"),&SpeedFxRaster::canvas_flame_blade);
    ClassDB::bind_method(D_METHOD("draco_dark_fall","center","age","warning","radius","clock","palette","fade"),&SpeedFxRaster::draco_dark_fall);
    ClassDB::bind_method(D_METHOD("canis_pixels","pixels","origin","cell","palette","fade","light_strength"),&SpeedFxRaster::canis_pixels);
    ClassDB::bind_method(D_METHOD("canis_hound_trails","trails","clock","palette","fade","light_strength"),&SpeedFxRaster::canis_hound_trails);
    ClassDB::bind_method(D_METHOD("monoceros_burns","burns","clock","radius","palette","fade"),&SpeedFxRaster::monoceros_burns);
    ClassDB::bind_method(D_METHOD("monoceros_crescent","points","head","tail","width","ramp","age","radius_scale","fade","light_strength"),&SpeedFxRaster::monoceros_crescent);
    ClassDB::bind_method(D_METHOD("ruler_beam","a","b","width","time","color","alpha","fade","light_strength"),&SpeedFxRaster::ruler_beam);
    ClassDB::bind_method(D_METHOD("auriga_trail","points","strengths","width","palette","clock","fade","light_strength"),&SpeedFxRaster::auriga_trail);
    ClassDB::bind_method(D_METHOD("lynx_scratch","origin","angle","side","size","span","cut","palette","settings","fade","light_strength"),&SpeedFxRaster::lynx_scratch);
    ClassDB::bind_method(D_METHOD("dolphin_band","center","radius","a0","a1","width","palette","alpha","dissolve","fade"),&SpeedFxRaster::dolphin_band);
    ClassDB::bind_method(D_METHOD("dolphin_arc","center","radius","a0","a1","color","alpha","fade"),&SpeedFxRaster::dolphin_arc);
    ClassDB::bind_method(D_METHOD("canvas_glow","center","radius","color","strength","fade","light_strength"),&SpeedFxRaster::canvas_glow);
    ClassDB::bind_method(D_METHOD("corona_vortex","owners","palette","fade"),&SpeedFxRaster::corona_vortex);
    ClassDB::bind_method(D_METHOD("density_field","points","radii","layers","origin","width","height","settings","palette","fade","light_strength"),&SpeedFxRaster::density_field);
    ClassDB::bind_method(D_METHOD("sweep_wake","tails","roots","ages","reach","fine","palette","time","fade"),&SpeedFxRaster::sweep_wake);
    ClassDB::bind_method(D_METHOD("ruler_rail","a","b","options","fade","light_strength"),&SpeedFxRaster::ruler_rail);
    ClassDB::bind_method(D_METHOD("begin","colors","lights","width","height","world_scale","camera"),&SpeedFxRaster::begin);
    ClassDB::bind_method(D_METHOD("begin_painter","painter","world_scale","camera","colors","lights"),&SpeedFxRaster::begin_painter);
    ClassDB::bind_method(D_METHOD("take_colors"),&SpeedFxRaster::take_colors);
    ClassDB::bind_method(D_METHOD("take_lights"),&SpeedFxRaster::take_lights);
    ClassDB::bind_method(D_METHOD("has_color"),&SpeedFxRaster::has_color);
    ClassDB::bind_method(D_METHOD("has_light"),&SpeedFxRaster::has_light);
    ClassDB::bind_method(D_METHOD("nova_field","alpha","emission","state","front"),&SpeedFxRaster::nova_field);
    ClassDB::bind_method(D_METHOD("reference_beam","a","b","palette","settings"),&SpeedFxRaster::reference_beam);
    ClassDB::bind_method(D_METHOD("corona_selection","from","to","charge","radius","intensity","palette","clock"),&SpeedFxRaster::corona_selection);
    ClassDB::bind_method(D_METHOD("corona_trail","center","direction","trail","age","clock","seed_angle","palette"),&SpeedFxRaster::corona_trail);
    ClassDB::bind_method(D_METHOD("dim","amount","flash"),&SpeedFxRaster::dim);
    ClassDB::bind_method(D_METHOD("breath","fan","elapsed","active","axis","sweep","half_angle","reach","fan_angle"),&SpeedFxRaster::breath);
    ClassDB::bind_method(D_METHOD("light_mask_reset"),&SpeedFxRaster::light_mask_reset);
    ClassDB::bind_method(D_METHOD("light_mask","mouth","pull","head","head_reach","axis","sweep","half_angle","reach","rocks","radius","strength"),&SpeedFxRaster::light_mask);
    ClassDB::bind_method(D_METHOD("exhale","at","angle","reach","width","beam_age","extend","life","time"),&SpeedFxRaster::exhale);
    ClassDB::bind_method(D_METHOD("comet","pos","angle","age","speed","radius","tail","shine","seed","with_star"),&SpeedFxRaster::comet);
    ClassDB::bind_method(D_METHOD("dark_shot","pos","angle","age","seed"),&SpeedFxRaster::dark_shot);
    ClassDB::bind_method(D_METHOD("tornado","center","radius","fade","grow","time"),&SpeedFxRaster::tornado);
    ClassDB::bind_method(D_METHOD("wind_band","mouth","angle","length","elapsed","active"),&SpeedFxRaster::wind_band);
    ClassDB::bind_method(D_METHOD("wind_blade","center","angle","age","life","size","side","seed"),&SpeedFxRaster::wind_blade);
    ClassDB::bind_method(D_METHOD("rock_comet","head","angle","speed","age","radius","seed","pace"),&SpeedFxRaster::rock_comet);
    ClassDB::bind_method(D_METHOD("sweep_band","path","start","rel","active","radius","color"),&SpeedFxRaster::sweep_band);
    ClassDB::bind_method(D_METHOD("bolt_bar","tail","angle","age","life","speed","length","width","color","time"),&SpeedFxRaster::bolt_bar);
}
void SpeedFxRaster::begin(PackedByteArray colors,PackedByteArray lights,int width,int height,double world_scale,Vector2 camera) {colors_=colors;lights_=lights;w_=width;h_=height;wl_=world_scale;camera_=camera;c_=colors_.ptrw();l_=lights_.ptrw();color_used_=false;light_used_=false;}
void SpeedFxRaster::begin_painter(Object *painter,double world_scale,Vector2 camera,bool colors,bool lights) {
    ERR_FAIL_NULL(painter);
    // 同期描画の間だけ元の参照を外す。別の所有者がいる配列は ptrw が従来どおり複製する。
    colors_=PackedByteArray();lights_=PackedByteArray();
    if (colors) {colors_=painter->get("colors");painter->set("colors",PackedByteArray());}
    if (lights) {lights_=painter->get("lights");painter->set("lights",PackedByteArray());}
    w_=painter->get("width");h_=painter->get("height");wl_=world_scale;camera_=camera;
    c_=colors_.ptrw();l_=lights_.ptrw();color_used_=false;light_used_=false;
}
PackedByteArray SpeedFxRaster::take_colors() {PackedByteArray out=colors_;colors_=PackedByteArray();c_=nullptr;return out;}
PackedByteArray SpeedFxRaster::take_lights() {PackedByteArray out=lights_;lights_=PackedByteArray();l_=nullptr;return out;}
void SpeedFxRaster::put(int x,int y,Color c) {if (x<0 || y<0 || x>=w_ || y>=h_) return;uint8_t *q=c_+(y*w_+x)*4;q[0]=uint8_t(c.r*255);q[1]=uint8_t(c.g*255);q[2]=uint8_t(c.b*255);q[3]=255;color_used_=true;}
void SpeedFxRaster::blend(float x,float y,Color c,double a) {if (a<=0.004) return;const int ix=int(std::floor(x)),iy=int(std::floor(y));if (ix<0 || iy<0 || ix>=w_ || iy>=h_) return;a=std::min(a,1.0);uint8_t *q=c_+(iy*w_+ix)*4;const double da=q[3]/255.0,oa=a+da*(1-a),k=a/oa;q[0]=uint8_t(int(c.r*255)*k+q[0]*(1-k));q[1]=uint8_t(int(c.g*255)*k+q[1]*(1-k));q[2]=uint8_t(int(c.b*255)*k+q[2]*(1-k));q[3]=uint8_t(oa*255);color_used_|=q[3]>0;}
void SpeedFxRaster::add(int x,int y,Color c,double k) {if (k<=0.004 || x<0 || y<0 || x>=w_ || y>=h_) return;uint8_t *q=l_+(y*w_+x)*4;q[0]=uint8_t(std::min(255.0,q[0]+int(c.r*255)*k));q[1]=uint8_t(std::min(255.0,q[1]+int(c.g*255)*k));q[2]=uint8_t(std::min(255.0,q[2]+int(c.b*255)*k));light_used_|=(q[0]|q[1]|q[2])!=0;}
void SpeedFxRaster::glow(float x,float y,float r,Color c,double strength) {if (r<1 || strength<=0.004) return;for (int sy=std::max(0,int(std::floor(y-r)));sy<=std::min(h_-1,int(std::ceil(y+r)));++sy) for (int sx=std::max(0,int(std::floor(x-r)));sx<=std::min(w_-1,int(std::ceil(x+r)));++sx) {const double d=std::hypot(sx+0.5-x,sy+0.5-y)/r;if (d<1) add(sx,sy,c,(1-d)*(1-d)*strength);}}
void SpeedFxRaster::disc(float cx,float cy,float r,Color c,double a) {const float r2=r*r;for (int sy=std::max(0,int(std::floor(cy-r)));sy<=std::min(h_-1,int(std::ceil(cy+r)));++sy) {const float dy=sy+0.5f-cy,s2=r2-dy*dy;if (s2<0) continue;const float s=std::sqrt(s2);for (int sx=std::max(0,int(std::ceil(cx-s-0.5f)));sx<=std::min(w_-1,int(std::floor(cx+s-0.5f)));++sx) {if (a>=1) put(sx,sy,c);else blend(sx,sy,c,a);}}}
void SpeedFxRaster::solid(float x,float y,float r,Color c) {if (r<0.6f) px(x,y,c);else disc(x,y,r,c,1);}
void SpeedFxRaster::soft(float x,float y,float r,Color c,double a) {if (a<=0.004) return;if (r<0.5f) blend(x,y,c,a);else disc(x,y,r,c,a);}
void SpeedFxRaster::fire_puff(float x,float y,double k,double size,double frac,const Color *H,int n,double glow_k,double tx,double ty) {const double age=1-k,heat=std::min(0.999,std::pow(age,0.62)+frac*0.1);const int idx=std::min(n-2,int(std::floor(heat*(n-1))));const float r=float(size*(0.55+0.45*std::min(1.0,age*7))*(1-age*0.55));const Color c=H[idx];if (idx>=n-2) {soft(x,y,r,c,std::min(1.0,k*3)*0.85);return;}solid(x,y,r,H[std::min(n-1,idx+2)]);if (r>1.6f && ty>-0.99) solid(float(x+tx*r*1.5),float(y+ty*r*1.5),r*0.3f,H[std::min(n-1,idx+1)]);solid(x-r*0.16f,y-r*0.22f,r*0.78f,c);if (r>1.6f) solid(float(x+tx*r*0.9),float(y+ty*r*0.9),r*0.42f,c);if (idx<=3 && r>1.8f) solid(x-r*0.28f,y-r*0.34f,r*0.36f,H[std::max(0,idx-1)]);if (idx<6) glow(x,y,r*2.4f+2,c,glow_k*k);}
void SpeedFxRaster::smoke_puff(float x,float y,double k,double size,Color c,double a_mul) {const double age=1-k;const float r=float(size*(0.65+std::min(1.0,age*2.5)*0.45+age*0.5));const double a=std::min(1.0,age*12)*std::min(1.0,k*2.4)*0.7*a_mul;soft(x,y,r,c,a*0.45);soft(x+r*0.05f,y+r*0.06f,r*0.74f,c,a*0.62);if (age<0.5) soft(x-r*0.22f,y-r*0.3f,r*0.5f,cmix(c,Color(1,1,1),0.12),a*0.4*(1-age*2));}
void SpeedFxRaster::blade(float x,float y,float ux,float uy,double length,double w,double bend,double time,double seed,const Color *H,const double (*layers)[3],int count,double jit,double wob) {if (length<1) return;const float nx=-uy,ny=ux;for (int l=0;l<count;++l) {const double lw=layers[l][0],lh=layers[l][1];const Color c=H[int(layers[l][2])];const double full=length*lh;for (double r=0;r<=full;r+=0.5) {const double u=r/std::max(1.0,full),half=w*lw*std::pow(1-u,0.85)*std::min(1.0,(r+1.5)/3.5)+N(time,9,seed,r*0.45)*jit;if (half<0.3) continue;const double off=bend*u*u*lh+N(time,4,seed+7,r*0.2)*u*wob;const float cx=float(x+ux*r+nx*off),cy=float(y+uy*r+ny*off);for (double q=-half;q<=half;q+=0.5) px(float(cx+nx*q),float(cy+ny*q),c);}}}
void SpeedFxRaster::star(Vector2 c,double size,double spin,double a,const Color *pal) {if (a<=0.02) return;px(c.x,c.y,pal[4]);for (int j=0;j<4;++j) {const double an=spin+j*PI/2,reach=size*(j%2?0.7:1);for (double d=0.5;d<=reach;d+=0.5) add(int(std::floor(c.x+std::cos(an)*d)),int(std::floor(c.y+std::sin(an)*d)),pal[d<reach*0.4?4:3],a*(1-d/(reach+0.5)));}glow(c.x,c.y,float(size*1.4),pal[2],0.35*a);}
// 暗くして光を際立たせる。体より奥の層へ描く。
void SpeedFxRaster::dim(double amount,double flash) {if (amount<=0.001 && flash<=0.001) return;const Color dark(4/255.0f,2/255.0f,12/255.0f),bright(190/255.0f,170/255.0f,1);for (int y=0;y<h_;++y) for (int x=0;x<w_;++x) {if (amount>0.001) blend(x,y,dark,amount);if (flash>0.001) blend(x,y,bright,flash);}}
// 星のブレス（pixelFX fire/fire-breath の作りを上から見た形へ）：炎の塊が口から吹き出され、減速しながらふくらんで紫へ冷え、煙になる。
void SpeedFxRaster::breath(PackedVector2Array fan,double e,double active,double axis,double sweep,double half_angle,double reach,double fan_angle) {
    if (fan.size()<3) return;const Color *H=FLAME;const Vector2 O=logical(fan[0]);const double L=reach*wl_,hw=half_angle*1.15,v0=L*2.3,drag=2,stop=active-0.2,rate=340;const int n=fan.size()-1;
    const auto angle_at=[&](double tb) {return axis+mix1(-sweep,sweep,smooth(0,1,tb/active));};
    const auto limit=[&](double lat) {return double(fan[0].distance_to(fan[1+std::min(n-1,std::max(0,int(std::round((lat*0.5+0.5)*(n-1)))))]))*wl_;};
    struct Q {double age,x,y,ux,uy,lat,fl,sl,size,f;bool sm;};std::vector<Q> live,smoke;
    for (int i=std::max(0,int(std::floor((e-1.7)*rate)));i/rate<std::min(e,stop);++i) {const double tb=i/rate,age=e-tb;const auto rnd=[&](double k) {return hash1(i*7.31+k*3.17);};const double lat=rnd(1)*2-1,fl=mix1(0.6,1.1,rnd(2))*(1-0.3*std::abs(lat)),sl=mix1(0.3,0.5,rnd(4));const bool sm=rnd(3)<0.25+0.4*std::abs(lat);if (age>fl+(sm?sl:0)) continue;const double way=wrap(angle_at(tb)-fan_angle),a=fan_angle+std::clamp(way,-hw*0.75,hw*0.75)+lat*hw*(0.55+0.45*smooth(0,0.25,age)),d=v0*mix1(0.75,1.1,rnd(5))/drag*(1-std::exp(-drag*age)),lim=limit(std::clamp(wrap(a-fan_angle)/half_angle,-1.0,1.0));if (d>lim-8) continue;const double ux=std::cos(a),uy=std::sin(a);Q q{age,O.x+ux*d+(rnd(8)-0.5)*d*0.05,O.y+uy*d+(rnd(9)-0.5)*d*0.05,ux,uy,lat,fl,sl,mix1(4,11,std::pow(rnd(6),1.6)),rnd(7),sm};if (age<fl) live.push_back(q);else if (sm) smoke.push_back(q);}
    for (const auto &q:smoke) smoke_puff(float(q.x),float(q.y),1-(q.age-q.fl)/q.sl,q.size*1.1,H[7],0.4);
    std::sort(live.begin(),live.end(),[](const Q &a,const Q &b) {return a.age>b.age;});
    for (const auto &q:live) {const double u=q.age/q.fl;soft(float(q.x),float(q.y),float(q.size*(1.4+2.2*u)),H[u<0.5?4:6],0.1*(1-u*0.6));}
    for (const auto &q:live) {const double u=q.age/q.fl,edge=std::abs(q.lat),size=q.size*(0.7+2*u),heat=std::min(0.999,std::pow(u,0.9)*(0.8+0.2*edge)+0.32*edge*edge),tear=clamp1((u-0.3)/0.2);fire_puff(float(q.x),float(q.y),1-heat,size*(1-0.45*tear),q.f,H,9,0.04,-q.ux*0.8,-q.uy*0.8);if (tear>0 && q.f<0.35) {const double id=std::floor(q.f*1e5),length=size*(1.2+0.5*N(e,4,id))*tear,sway=N(e,2.5,id+1)*0.5+q.lat*0.5,cs=std::cos(sway),sn=std::sin(sway);if (heat<0.5) blade(float(q.x),float(q.y),float(q.ux*cs-q.uy*sn),float(q.uy*cs+q.ux*sn),length,std::min(4.0,size*0.2),N(e,2.5,id+2)*2,e,id,H,BACK_LAYERS,4,0.5,1.1);else blade(float(q.x),float(q.y),float(q.ux*cs-q.uy*sn),float(q.uy*cs+q.ux*sn),length,std::min(4.0,size*0.2),N(e,2.5,id+2)*2,e,id,H,COOL_LAYERS,3,0.5,1.1);}}
    const double roar=0.85+0.15*N(e,3,7),on=1-smooth(stop-0.12,stop,e);
    if (on>0) {const double offs[4]={0,-0.1,0.1,0},lens[4]={30,23,23,15},wid[4]={3.6,3.2,3.2,4};for (int i=0;i<4;++i) blade(O.x,O.y,float(std::cos(fan_angle+offs[i])),float(std::sin(fan_angle+offs[i])),lens[i]*roar*on,wid[i],N(e,3,i+3)*3,e,30+i*17,H,LAYERS,4,0.5,1.5);glow(O.x,O.y,7,H[3],0.5*on);}
    const Ramp pal(Color(0xab/255.0f,0x9c/255.0f,1));for (int i=0;i<16;++i) {const int j=1+int(std::floor(hash1(i*4.3)*n));const Vector2 span=fan[j]-fan[0];const double far=span.length();if (far<1) continue;const double at=std::fmod(e*1100+hash1(i*6.6)*1500,far);star(logical(fan[0]+span/far*at),1.4,e*6+i,on*0.65,pal.v);}
}
void SpeedFxRaster::light_mask_reset() {mask_.clear();}
// ためた光が口から強く広がり、隕石の裏に本物の影が落ちる。首の振りのどの位置から見えるかの割合で影の境目がぼやける。
void SpeedFxRaster::light_mask(Vector2 mouth,double pull,Vector2 head,double head_reach,double axis,double sweep,double half_angle,double reach,PackedVector2Array rocks,double radius,double strength) {
    if (mask_.empty()) {
        const int rays=9;Vector2 mouths[rays];for (int i=0;i<rays;++i) mouths[i]=head+Vector2::from_angle(axis-sweep+2*sweep*i/(rays-1))*head_reach;
        const auto hit=[&](Vector2 m,Vector2 p) {const Vector2 d=p-m;const double l2=d.length_squared();for (int q=0;q<rocks.size();++q) {const Vector2 f=rocks[q]-m;const double u=clamp1(double(f.dot(d))/l2);if (u>0 && u<1 && (m+d*u).distance_to(rocks[q])<radius*0.97 && p.distance_to(rocks[q])>radius) return true;}return false;};
        const double wide=sweep+half_angle;mask_.assign(size_t(w_)*h_,0);mask_camera_=camera_;
        for (int y=0;y<h_;++y) for (int x=0;x<w_;++x) {const Vector2 p=Vector2((x-w_/2.0)/wl_+camera_.x,(y-h_/2.0)/wl_+camera_.y),off=p-mouth;const double d=off.length();if (d>reach) continue;const double ang=std::abs(wrap(off.angle()-axis)),inside=1-smooth(wide*0.8,wide*1.1,ang);if (inside<=0) continue;int seen=0;for (int m=0;m<rays;++m) if (!hit(mouths[m],p)) ++seen;mask_[y*w_+x]=float(std::pow(1-d/reach,1.2)*inside*seen/rays);}
        std::vector<float> o(mask_.size());const int R3=3;for (int pass=0;pass<3;++pass) {for (int y=0;y<h_;++y) for (int x=0;x<w_;++x) {int n=0;float s=0;for (int k=-R3;k<=R3;++k) {const int c=x+k;if (c>=0 && c<w_) {s+=mask_[y*w_+c];++n;}}o[y*w_+x]=s/n;}for (int y=0;y<h_;++y) for (int x=0;x<w_;++x) {int n=0;float s=0;for (int k=-R3;k<=R3;++k) {const int c=y+k;if (c>=0 && c<h_) {s+=o[c*w_+x];++n;}}mask_[y*w_+x]=s/n;}}
    }
    const float ox=float((camera_.x-mask_camera_.x)*wl_),oy=float((camera_.y-mask_camera_.y)*wl_);for (int y=0;y<h_;++y) for (int x=0;x<w_;++x) {const float f=mask_[y*w_+x];if (f>0.008f) blend(x-ox,y-oy,FLAME[4],0.5*f*strength);}
}
// 吐き出し：宇宙の光の奔流。桃と水色の星雲が流れ、二重らせんが巻きつき、光の節が走る。
void SpeedFxRaster::exhale(Vector2 at,double angle,double reach,double width,double beam_age,double extend,double life,double t) {
    if (life<=0) return;const double ux=std::cos(angle),uy=std::sin(angle);const Vector2 O=logical(at);const double burst=1-std::pow(1-clamp1(beam_age/extend),3.0),L=reach*wl_*burst,hw=width*0.5*wl_*life,halo=hw*3.2,pad=halo+6;const Color *H=FLAME;double pulses[3];for (int i=0;i<3;++i) pulses[i]=std::fmod(t*1.1+i/3.0,1.0)*L;
    const double x0=std::min(O.x-ux*8,O.x+ux*L)-pad,x1=std::max(O.x-ux*8,O.x+ux*L)+pad,y0=std::min(O.y-uy*8,O.y+uy*L)-pad,y1=std::max(O.y-uy*8,O.y+uy*L)+pad;
    for (int sy=std::max(0,int(y0));sy<=std::min(h_-1,int(y1));++sy) for (int sx=std::max(0,int(x0));sx<=std::min(w_-1,int(x1));++sx) {
        const double x=sx+0.5,y=sy+0.5,dx=x-O.x,dy=y-O.y,along=dx*ux+dy*uy,lat=dy*ux-dx*uy,abs_lat=std::abs(lat);if (abs_lat>halo*1.4 || along<-8 || along>L+8) continue;
        double node=0;for (double c:pulses) {const double e=(along-c)/16;node=std::max(node,std::exp(-e*e));}
        const double w=hw*mix1(0.55,1,smooth(-4,34,along))*(1+0.14*std::sin(along*0.075-t*24)+0.08*std::sin(along*0.17-t*37+1)+0.42*node),q=abs_lat/w,tip=1-smooth(L-8,L+6,along),base=smooth(-8,3,along)*tip,flow=0.5+0.5*fbm(along*0.02-t*7,lat*0.1,41,3),hue=0.5+0.5*fbm(along*0.009-t*3.2,lat*0.04+3,17,2);const Color neb=cmix(PINK,CYAN,smooth(0.3,0.7,hue));
        if (q>1) {const double g=clamp1(1-(abs_lat-w)/(halo*(1+0.3*flow)-w));if (g>0) blend(sx,sy,g>0.55?neb:H[6],g*g*(0.62+0.25*node)*base);}
        else {const double core=clamp1((1-q*q)*(0.85+0.5*flow)+node*0.35);blend(sx,sy,core>0.72?cmix(H[2],H[0],smooth(0.72,0.95,core)):core>0.34?cmix(neb,H[2],smooth(0.34,0.72,core)):cmix(H[6],neb,smooth(0,0.34,core)),base);}
        for (int k=0;k<2;++k) {const double ph=along*0.052-t*15+k*PI,yy=std::sin(ph)*w*1.18,d=std::abs(lat-yy),front=0.55+0.45*std::cos(ph);if (d<2.2) blend(sx,sy,k?PINK:CYAN,(1-d/2.2)*(0.5+0.5*front)*base);}
    }
    for (double c:pulses) glow(float(O.x+ux*c),float(O.y+uy*c),float(hw*2.2),CYAN,0.3*clamp1(life));
    const Ramp pal(Color(0xab/255.0f,0x9c/255.0f,1)),pink(hexc(0xff9ae6)),cyan(hexc(0x9fefff));
    for (int i=0;i<34;++i) {const double ph=std::fmod(t*(0.9+hash1(i)*1.3)+hash1(i*3.3),1.0),along=ph*L,side=hash1(i*7.1)>0.5?1:-1,off=side*hw*(1.25+1.9*ph*hash1(i*5.1))+std::sin(along*0.03+i)*5,on=std::sin(PI*ph)*clamp1(life);const Vector2 c(float(O.x+ux*along-uy*off),float(O.y+uy*along+ux*off));if (i%3==0) star(c,3+6*hash1(i*2.2),t*4+i,on,(hash1(i)>0.5?pink:cyan).v);else blend(c.x,c.y,i%2?PINK:CYAN,on);}
    const double big=(24+5*std::sin(t*19))*std::min(1.3,life);star(O,big,t*1.4,clamp1(life),pal.v);star(O,big*0.7,-t*2.1+0.6,clamp1(life)*0.8,cyan.v);glow(O.x,O.y,float(hw*2.6),PINK,0.55*clamp1(life));glow(O.x,O.y,float(hw*1.3),H[0],0.8*clamp1(life));
}
// 彗星弾：渦巻く星雲の玉が、ねじれながら揺れる光のリボンと星屑を引く。リボンの表と裏で桃と水色が入れ替わる。
void SpeedFxRaster::comet(Vector2 pos,double angle,double age,double speed,double radius,double tail,double shine,double seed,bool with_star) {
    const Color *H=FLAME;const double ux=std::cos(angle),uy=std::sin(angle),on=smooth(0,0.12,age);const Vector2 head=logical(pos);const double rad=radius*wl_*1.7*on,L=std::min(age*speed,tail*1.5)*wl_,nx=-uy,ny=ux;
    const auto wave=[&](double d) {return std::sin(d*0.035-age*9+seed)*(d/std::max(1.0,L))*rad*2.2;};
    for (double d=0;d<L;d+=0.5) {const double f=d/L,off=wave(d),tw=std::sin(d*0.085-age*15+seed),w=rad*1.05*std::pow(1-f,0.9)*(0.25+0.75*std::abs(tw));const Color c=tw>0?PINK:CYAN;const double x=head.x-ux*d+nx*off,y=head.y-uy*d+ny*off;for (double o=-w;o<=w;o+=0.5) {const double e=std::abs(o)/std::max(0.5,w);blend(float(x+nx*o),float(y+ny*o),e<0.35?cmix(c,H[1],(1-f)*0.8):c,(1-f)*(1-e*e)*0.85*on);}}
    const Ramp pink(hexc(0xff9ae6)),cyan(hexc(0x9fefff)),pal(Color(0xab/255.0f,0x9c/255.0f,1));
    for (int i=0;i<12;++i) {const double ph=std::fmod(age*(1.2+hash1(i+seed))+hash1(i*3.3+seed),1.0),d=ph*L,off=wave(d)+(hash1(i*5.7+seed)-0.5)*rad*3.4*ph,x=head.x-ux*d+nx*off,y=head.y-uy*d+ny*off;if (i%3==0) star(Vector2(float(x),float(y)),2.4,age*7+i,(1-ph)*on,(i%2?pink:cyan).v);else blend(float(x),float(y),H[1],(1-ph)*on);}
    const int R2=int(std::ceil(rad))+1;for (int dy=-R2;dy<=R2;++dy) for (int dx=-R2;dx<=R2;++dx) {const double d=std::hypot(dx,dy)/std::max(1.0,rad);if (d>1) continue;const double ang=std::atan2(dy,dx)+d*3-age*6,n=0.5+0.5*std::sin(ang*2+seed);blend(head.x+dx,head.y+dy,d<0.42?H[0]:d>0.82?H[4]:cmix(PINK,CYAN,n),1);}
    glow(head.x,head.y,float(rad*2.6),VIOLET,shine*on);star(head,rad*1.9,age*3+seed,on,pal.v);if (with_star) star(head,7,age*5,0.8,pal.v);
}
// 闇の矢：黒い槍の形に紫の縁が走り、闇の煙を引く。
void SpeedFxRaster::dark_shot(Vector2 pos,double angle,double age,double seed) {
    const Color *H=DARK;const Vector2 tip=logical(pos);const double ux=std::cos(angle),uy=std::sin(angle),L=58,W=11,nx=-uy,ny=ux;
    for (int i=0;i<14;++i) {const double d=L*0.6+(i*13+std::fmod(age*900*((i%3)*0.1+0.2),13.0)),off=(hash1(i*3.3+seed)-0.5)*(6+i*1.1),f=i/14.0;soft(float(tip.x-ux*d+nx*off),float(tip.y-uy*d+ny*off),float(7-f*3),H[i%3?5:4],0.5*(1-f));}
    for (double d=0;d<L;d+=0.5) {const double f=d/L,w=(f<0.3?f/0.3:std::pow(1-(f-0.3)/0.7,0.7))*W*(1+0.16*std::sin(d*0.9+age*40+seed)*f);for (double o=-w;o<=w;o+=0.5) {const double e=std::abs(o)/std::max(0.5,w);blend(float(tip.x-ux*d+nx*o),float(tip.y-uy*d+ny*o),e>0.8?H[2]:e>0.55?H[4]:H[7],e>0.8?1:0.97);}blend(float(tip.x-ux*d+nx*w),float(tip.y-uy*d+ny*w),H[1],1-f*0.5);blend(float(tip.x-ux*d-nx*w),float(tip.y-uy*d-ny*w),H[1],1-f*0.5);}
    glow(float(tip.x-ux*L*0.4),float(tip.y-uy*L*0.4),20,H[2],0.55);
}
// 瓦礫竜巻：見下ろしの渦。らせんの腕が中心へ巻き込み、緑の風の腕に瓦礫の砂ぼこりの腕が混ざる。
void SpeedFxRaster::tornado(Vector2 center,double radius,double fade,double grow,double t) {
    const Color *C=WIND;const Color DUST[2]={hexc(0x9a8f86),hexc(0x7a7068)};const Color STONE3=hexc(0x6f7f8d),STONE2=hexc(0x4b5a68);const Vector2 L=logical(center);const double Rr=radius*wl_,turn=t*10;if (Rr<1) return;
    const auto ramp=[&](double v) {const double q=clamp1(v)*5;const int i=std::min(4,int(std::floor(q)));return cmix(C[1+i],C[2+i],q-i);};
    for (int sy=std::max(0,int(L.y-Rr*1.2));sy<=std::min(h_-1,int(L.y+Rr*1.2));++sy) for (int sx=std::max(0,int(L.x-Rr*1.2));sx<=std::min(w_-1,int(L.x+Rr*1.2));++sx) {const double dx=sx+0.5-L.x,dy=sy+0.5-L.y,r=std::hypot(dx,dy)/Rr;if (r>1.15) continue;const double ph=std::atan2(dy,dx),tw=5.2*std::log(r+0.1),n=fbm((ph/TAU+0.5)*8,r*3-t*1.4,37,2),n2=fbm((ph/TAU+0.5)*16,r*6-t*3,11,2),big=std::pow(0.5+0.5*std::cos(3*ph+tw+turn),1.2),thin=std::pow(0.5+0.5*std::cos(7*ph+tw*1.25+turn*1.5+1.3),1.6),arm=clamp1((0.72*big+0.42*thin)*(0.72+0.8*n)),grit=clamp1(std::pow(0.5+0.5*std::cos(2*ph+tw+turn+2.1),3.0)*smooth(0.3,0.75,r)*(0.5+1.1*n2)),env=smooth(0.03,0.16,r)*(1-smooth(0.82,1.12,r)),core=1-smooth(0.04,0.12,r),a=(0.62+0.36*arm)*env*fade;if (core>0) blend(sx,sy,C[0],core*0.85*fade);if (a>0.015) blend(sx,sy,ramp(arm*(1.12-0.4*r)),a);if (grit*env>0.03) blend(sx,sy,DUST[n2>0.5?0:1],grit*env*0.8*fade);}
    for (int k=0;k<16;++k) {const double a0=k*TAU/16+hash1(k*3.1)*1.2-t*12*(0.85+0.3*hash1(k*5.3)),r0=mix1(0.14,0.5,hash1(k*2.7)),r1=r0+mix1(0.3,0.55,hash1(k*7.9));const int n=int(std::ceil(Rr*3));for (int m=0;m<=n;++m) {const double u=double(m)/n,rr=mix1(r0,r1,u),ang=a0-5.2/3*std::log(rr+0.1),f=std::sin(PI*u);blend(float(L.x+std::cos(ang)*rr*Rr),float(L.y+std::sin(ang)*rr*Rr),C[k%3==0 && f>0.7?7:6],f*f*(k%3==0?0.8:0.5)*fade);}}
    for (int i=0;i<44;++i) {const double seed=53,life=mix1(0.7,1.1,hash1(i*3.7+seed)),off=hash1(i*9.1+seed)*life,c=std::floor((t+off)/life),age=t+off-c*life;const auto rnd=[&](double k) {return hash1(i*13.1+c*7.3+k*1.91+seed);};const double k=age/life,rr=mix1(1.3,0.14,std::pow(k,1.3))*Rr,th=rnd(1)*TAU-mix1(2,3,rnd(2))*TAU*std::pow(k,1.6),a=std::min(1.0,k*6)*(1-smooth(0.8,1,k))*fade*grow,spin=age*mix1(-14,14,rnd(4));const bool leaf=rnd(3)<0.45;const float x=float(L.x+std::cos(th)*rr),y=float(L.y+std::sin(th)*rr);blend(x,y,leaf?C[5]:STONE3,a);blend(float(x+std::round(std::cos(spin))),float(y+std::round(std::sin(spin))),leaf?C[4]:STONE2,a);}
}
// 風の帯（竜巻）：横倒しの竜巻を上から見た形。口から先へ広がる円錐の中を、ねじれた風の筋がらせんに回る。pixelFX ice/frost-breath の作り（Hugo Duprez、MIT）。
void SpeedFxRaster::wind_band(Vector2 mouth,double angle,double L,double e,double active) {
    const Color *C=WIND;const Vector2 dir=Vector2::from_angle(angle),sd(-dir.y,dir.x);const double R0=32,R1=115,end=e>active?clamp1(1-(e-active)/0.45):1;if (end<=0) return;const double front=std::min(L*1.12,e*2200),tail=e>active?(e-active)*700:0,step=0.5/wl_;
    const auto rad=[&](double s) {return mix1(R0,R1,std::pow(clamp1(s/L),0.85));};const auto W=[&](double s,double y) {return logical(mouth+dir*s+sd*y);};const auto far=[&](double s) {return 1-smooth(L*0.68,L*1.1,s);};const auto fade_s=[&](double s) {return clamp1((s-tail)/30)*clamp1((front-s)/30)*far(s)*end;};
    {const Vector2 A=W(std::max(6.0,tail),0),B=W(std::max(tail+1,L*0.95),0);const int n=int(A.distance_to(B)/4)+1;for (int i=0;i<=n;++i) {const Vector2 q=A.lerp(B,float(i)/n);glow(q.x,q.y,7,C[4],0.22*end/3);}glow(A.x,A.y,6,C[6],0.45*end);}
    for (int k=0;k<4;++k) {const double ph=k*TAU/4+hash1(k*3.3)*0.6;for (double s=tail;s<=front;s+=step) {const double th=s*(0.05-0.00004*s)-e*(13+4*hash1(k))+ph+std::sin(s*0.02+k*2.1-e*3)*0.5,depth=0.5+0.5*std::sin(th),f=fade_s(s)*(0.25+0.75*clamp1(s/40))*clamp1(0.55+0.9*fbm(s*0.03-e*6,k*3.1,31,2));if (f<=0.04) continue;const double fr=far(s);if (fr<0.95 && hash1(k*31+std::floor(s*wl_*2)*7+std::floor(e*24))>fr*1.25) continue;const Vector2 q=W(s,rad(s)*(1+0.14*std::sin(s*0.03+k*2-e*5)+(1-fr)*0.25*std::sin(s*0.11+k))*std::cos(th));const double w=(0.3+1.4*depth)*(0.6+0.4*std::min(1.0,s/L))*(0.35+0.65*fr),b=f*(0.3+0.7*depth);for (double o=-w;o<=w;o+=0.5) {const float x=float(q.x+sd.x*o),y=float(q.y+sd.y*o);const double ee=std::abs(o)/std::max(0.5,w);if (depth>0.55 && b>0.5) px(x,y,C[ee<0.4 && depth>0.8?7:6]);else blend(x,y,depth>0.5?C[5]:C[3],std::min(0.85,b*(1-ee*0.5)));}if (depth>0.5) add(int(q.x),int(q.y),C[5],0.18*b);}}
    const auto cycle=[&](int count,double life0,double life1,double seed,auto fn) {for (int i=0;i<count;++i) {const auto rnd=[&](double k) {return hash1(i*7.31+k*3.17+seed);};const double life=mix1(life0,life1,rnd(9)),off=rnd(8)*life;const double c=std::floor((e+off)/life),born=c*life-off;if (born<0 || born>active) continue;const auto rn=[&](double k) {return hash1(i*7.31+k*3.17+seed+c*1.7);};fn(e-born,life,rn);}};
    cycle(10,0.32,0.42,21,[&](double age,double life,auto rnd) {const double k=age/life,s0=mix1(10,40,rnd(1))+age*mix1(650,850,rnd(2))*L/340;if (s0>L*1.1) return;const double rr=rad(s0)*mix1(0.85,1.05,rnd(3)),rx=rr*0.26,phi0=rnd(4)*TAU-e*14,span=mix1(3.4,4.4,rnd(5)),fa=std::sin(PI*k)*fade_s(s0);for (int m=0;m<=40;++m) {const double u=m/40.0,phi=phi0+span*u,depth=0.5+0.5*std::sin(phi);const Vector2 q=W(s0+rx*std::sin(phi),rr*std::cos(phi));const double b=fa*std::sin(PI*u)*(0.35+0.65*depth),w=0.3+1.1*std::sin(PI*u)*depth;if (b<0.12) continue;for (double o=-w;o<=w;o+=0.5) {const float x=float(q.x+dir.x*o),y=float(q.y+dir.y*o);if (b>0.5 && depth>0.5) px(x,y,C[std::abs(o)<w*0.5?7:6]);else blend(x,y,C[depth>0.5?5:4],std::min(0.8,b));}if (depth>0.6) add(int(q.x),int(q.y),C[5],0.2*b);}});
    cycle(14,0.5,0.7,23,[&](double age,double,auto rnd) {const double s0=age*mix1(380,520,rnd(1));if (s0>L) return;const double th=rnd(2)*TAU+s0*0.042-e*15,depth=0.5+0.5*std::sin(th),spin=age*18+rnd(3)*6;if (fade_s(s0)<0.2) return;const Vector2 q=W(s0,rad(s0)*0.85*std::cos(th));px(q.x,q.y,depth>0.5?C[5]:C[3]);px(float(q.x+std::round(std::cos(spin))),float(q.y+std::round(std::sin(spin))),depth>0.5?C[6]:C[4]);});
}
// 三日月の風刃：ふちが一瞬で弧を走って開き、頭の側が太く尾の側へ長く細く伸びる。後ろ側は毛羽立ちになって緑へ溶ける。
void SpeedFxRaster::wind_blade(Vector2 c,double angle,double age,double life,double size,double d,double seed) {
    const Color *C=WIND;const Color white(1,1,1);const double stops[5]={0,0.5,0.72,0.9,1};const Color cols[5]={white,white,C[6],C[5],C[4]};const auto ramp=[&](double q) {int i=0;while (i<3 && q>stops[i+1]) ++i;return cmix(cols[i],cols[i+1],clamp1((q-stops[i])/(stops[i+1]-stops[i])));};
    const Vector2 dir=Vector2::from_angle(angle);const double Rw=size*1.133;const Vector2 O=logical(c-dir*(Rw-size*0.6));const double Rl=Rw*wl_,span=2.55,a0=angle-d*span/2,U=span*(1-std::pow(2,-10*age/0.12)),T=span*smooth(life-0.5,life,age),W=46*wl_,reach=W*3.2+3,shine=std::fmod(age*2.2,1.5)-0.25;if (U-T<0.02) return;
    const auto profile=[](double v) {return std::pow(std::sin(PI*std::pow(v,1.7)),0.8);};const auto fur=[&](double u,double e) {const double x=(u+e/Rl*0.9+age*0.5)/span*20,i=std::floor(x),t=x-i;return (0.45+0.75*hash1(i*3.7+seed))*std::pow(1-std::abs(2*t-1),1.3);};
    for (int sy=std::max(0,int(O.y-Rl-3));sy<=std::min(h_-1,int(O.y+Rl+3));++sy) for (int sx=std::max(0,int(O.x-Rl-3));sx<=std::min(w_-1,int(O.x+Rl+3));++sx) {const double dx=sx+0.5-O.x,dy=sy+0.5-O.y,rr=std::hypot(dx,dy),e=Rl-rr;if (e<-1.5 || e>reach) continue;double u=wrap(std::atan2(dy,dx)-a0)*d;if (u<-0.5) u+=TAU;if (u<T || u>U) continue;const double v=(u-T)/(U-T),w=W*profile(v);if (w<0.25) continue;const double q=e/w,tail=smooth(0,0.14,v),g=(v-shine)/0.16,glint=std::exp(-g*g);if (e<=0) {blend(sx,sy,C[5],tail*(1+e/1.5)*0.55);continue;}if (q<=0.55) {blend(sx,sy,ramp(clamp1(q/0.55-0.3*glint)),tail);continue;}const double over=(e-w*0.55)/std::max(0.5,W*profile(v)*fur(u,e)*1.5);if (over>1) continue;const double f=clamp1(over);blend(sx,sy,cmix(C[6],C[4],f),tail*std::pow(1-f,0.8)*0.9);}
    for (int m=0;m<12;++m) {const double a=a0+d*mix1(T,U,(m+0.5)/12),radius=Rl-W*0.3;glow(float(O.x+std::cos(a)*radius),float(O.y+std::sin(a)*radius),11,C[4],0.24*profile(m/12.0)*0.5);}
}
// 飛ぶ岩の尾：岩の後ろから土煙の舌が何本も流れ、うねりが尾へ速く走り、先へ細く薄くなる。pixelFX fire/meteor の作りを土煙で。
void SpeedFxRaster::rock_comet(Vector2 world,double angle,double speed,double age,double radius,double seed,double pace) {
    const Color DUST[3]={hexc(0x9a8f86),hexc(0x7a7068),hexc(0xc9bfb2)};const Vector2 head=logical(world);const double ux=std::cos(angle),uy=std::sin(angle),rad=radius*wl_*1.1,on=smooth(0,0.06,age),full=speed*0.42*wl_,L=std::min(speed*age*wl_,full);
    struct T {double off,len,ph,wid;} tongues[6];for (int i=0;i<6;++i) tongues[i]={(i/5.0-0.5)*1.5,mix1(0.55,1,hash1(i*3.1+2)),hash1(i*5.7)*TAU,mix1(0.32,0.55,hash1(i*2.3+7))};
    if (L>2) {const double x0=std::min(double(head.x),head.x-ux*L)-rad*1.6,x1=std::max(double(head.x),head.x-ux*L)+rad*1.6,y0=std::min(double(head.y),head.y-uy*L)-rad*1.6,y1=std::max(double(head.y),head.y-uy*L)+rad*1.6;for (int sy=std::max(0,int(y0));sy<=std::min(h_-1,int(y1));++sy) for (int sx=std::max(0,int(x0));sx<=std::min(w_-1,int(x1));++sx) {const double dx=sx+0.5-head.x,dy=sy+0.5-head.y,along=-(dx*ux+dy*uy),lat=-dx*uy+dy*ux,k0=along/L;if (k0<-0.04 || k0>1) continue;double a=0,k1=0;for (const auto &t:tongues) {const double k=k0/t.len;if (k>1) continue;const double c=rad*(t.off*(1-k*0.75)+std::sin(k*7-age*34*pace+t.ph)*0.26*clamp1(k*2.2)),w=rad*t.wid*std::pow(1-std::max(k,0.0),0.75)*(0.6+0.4*clamp1(k*4)),e=1-std::abs(lat-c)/std::max(0.4,w);if (e<=0) continue;const double v=smooth(0,0.5,e)*std::pow(1-std::max(k,0.0),1.3)*0.85;if (v>a) {a=v;k1=k;}}if (a>0.02) blend(sx,sy,cmix(DUST[2],DUST[1],clamp1(k1*1.5)),a*on);}}
    const Vector2 start=world-Vector2::from_angle(angle)*speed*age;for (int i=std::max(0,int(std::floor((age-0.45)*26)));i/26.0<=age;++i) {const double born=i/26.0;const auto rnd=[&](double k) {return hash1(i*7.31+k*3.17+seed);};const double life=mix1(0.2,0.45,rnd(1)),k=1-(age-born)/life;if (k<=0) continue;const Vector2 dv=Vector2::from_angle(angle);const Vector2 q=logical(start+dv*(speed*born-radius)+Vector2(-dv.y,dv.x)*(rnd(3)-0.5)*radius*1.5);const double len=mix1(5,14,rnd(2))*mix1(0.4,1,pace);for (double t=0;t<len;t+=0.5) blend(float(q.x-ux*t),float(q.y-uy*t),DUST[rnd(6)<0.5?0:1],k*k*(1-t/len)*0.6);}
}
// 薙ぎ払いの帯：頭の通った道に沿う筋の束。真ん中の筋ほど長く残り、先が太く後ろが細る三日月になる。path は start 秒から1/300秒ごとの頭の位置。
void SpeedFxRaster::sweep_band(PackedVector2Array path,double start,double rel,double active,double radius,Color color) {
    if (path.size()<2) return;const Ramp r(color);const Color *pal=r.v;const double half=radius*0.55*wl_,dt=1.0/300,max_age=0.34;
    const auto at=[&](double q) {const double u=std::clamp((q-start)*300,0.0,double(path.size()-1));const int i=std::min(int(u),int(path.size())-2);return logical(path[i].lerp(path[i+1],float(u-i)));};
    for (double o=-half;o<=half;o+=0.75) {const double e=std::abs(o)/half,lane=std::round(o/0.75),life=max_age*(1-std::pow(e,1.6))*(0.5+0.5*hash1(lane*3.7+1));if (life<=0.01) continue;
        for (double age=std::max(0.0,rel-active);age<=life;age+=dt) {const double q=rel-age;if (q<0) break;const Vector2 A=at(q),B=at(std::max(0.0,q-dt)),tangent=(A-B).normalized(),n(-tangent.y,tangent.x);const double k=age/life;const float x=A.x+n.x*o,y=A.y+n.y*o;
            if (k>0.55 && hash1(lane*11+std::floor(q*300)*5)>(1-k)*2.2) continue;
            const double speed=A.distance_to(B)/dt/wl_,al=(1-k)*(1-e*0.7)*smooth(200,900,speed);const int level=k<0.12 && e<0.35?4:k<0.4?3:2;if (al<0.03) continue;
            if (al>0.6 && e<0.25) px(x,y,pal[level]);else if (al*(1-e)>0.18) blend(x,y,pal[std::max(1,level-1)],al*(1-e)*0.9);
            add(int(std::floor(x)),int(std::floor(y)),pal[2],al*(1-e)*0.1);}}
}
// 光の棒：両端がとがり、前寄りが一番太い。芯が白く、縁へ冷える。後ろにちらつく光の粒を引く。
void SpeedFxRaster::bolt_bar(Vector2 tail,double angle,double age,double life,double speed,double length,double width,Color color,double t) {
    const Ramp r(color);const Color *pal=r.v;const Vector2 dir=Vector2::from_angle(angle),sd(-dir.y,dir.x);const double fade=clamp1((life-age)/0.3),tick20=std::floor(t*20),tick30=std::floor(t*30);
    for (int k=1;k<26;++k) {if (age*speed<k*6) break;const Vector2 q=logical(tail-dir*k*6);const double f=(1-k/26.0)*fade;add(int(q.x+(hash1(k+tick20)-0.5)*2),int(q.y+(hash1(k*3+tick20)-0.5)*2),pal[2],f*0.35);if (hash1(k*7+tick30)<f*0.5) blend(q.x,q.y,pal[3],f);}
    const Vector2 A=logical(tail);const double Lp=length*wl_,hw=width*0.5*wl_;for (double d=0;d<=Lp;d+=0.5) {const double k=d/Lp,tp=std::pow(std::min({1.0,k/0.45,(1-k)/0.12}),0.7),w=std::max(0.5,hw*tp);const float cx=float(A.x+dir.x*d),cy=float(A.y+dir.y*d);for (double o=-w;o<=w;o+=0.5) {const double e=std::abs(o)/w;if (fade>0.6 || hash1(d*7+o*13+tick30)<fade*1.4) px(float(cx+sd.x*o),float(cy+sd.y*o),pal[e<0.3?4:e<0.65?3:2]);}if (int(d)%2==0) add(int(cx),int(cy),pal[2],0.35*fade);}
    glow(float(A.x+dir.x*Lp*0.7),float(A.y+dir.y*Lp*0.7),float(hw*2.2),pal[2],0.35*fade);
}

// Painter.dot の明るさ・ディザを保ち、内側の画素ループだけをまとめて処理する。
void SpeedFxRaster::reference_dot(double x,double y,Color color,double alpha) {
    if (alpha<=0 || color.a<=0) return;
    const int ix=int(std::floor(x)),iy=int(std::floor(y));
    if (ix<0 || iy<0 || ix>=w_ || iy>=h_) return;
    constexpr int bayer[16]={0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5};
    double k=1;
    if (alpha>=0.12 && alpha<0.999) k=0.2+0.8*alpha;
    else if (alpha<1 && alpha<=(bayer[((iy&3)<<2)|(ix&3)]+0.5)/16.0) return;
    uint8_t *q=c_+(iy*w_+ix)*4;
    q[0]=uint8_t(clamp1(color.r)*255.0*k);
    q[1]=uint8_t(clamp1(color.g)*255.0*k);
    q[2]=uint8_t(clamp1(color.b)*255.0*k);
    q[3]=k!=1?255:uint8_t(clamp1(color.a)*255.0);
    color_used_|=q[3]>0;
}
void SpeedFxRaster::reference_add(int x,int y,Color color,double strength) {
    if (strength<=0.004 || x<0 || y<0 || x>=w_ || y>=h_) return;
    uint8_t *q=l_+(y*w_+x)*4;
    q[0]=uint8_t(std::min(255.0,q[0]+int(double(color.r)*255.0)*strength));
    q[1]=uint8_t(std::min(255.0,q[1]+int(double(color.g)*255.0)*strength));
    q[2]=uint8_t(std::min(255.0,q[2]+int(double(color.b)*255.0)*strength));
    light_used_|=(q[0]|q[1]|q[2])!=0;
}



void SpeedFxRaster::nova_field(PackedByteArray alpha,PackedFloat32Array emission,Dictionary state,bool front) {
    const int width=state["width"],height=state["height"];
    const double cell=state["cell"],aperture=state["aperture"],range_end=state["range_end"],t=state["t"],tell=state["tell"],burst=state["burst"],gain=state["gain"];
    const Vector2 source=state["source"],origin=state["origin"];
    if (width<=0 || height<=0 || cell<=0 || alpha.size()!=int64_t(width)*height || emission.size()!=192*192 || aperture<=0) return;
    const Color tint=hexc(0x9caec0),flash=hexc(0xe8f4ff),corona=hexc(0x6a9bca),hot=hexc(0xfff0cc);
    const double stretch=t<0?1:1+0.45*burst,exposure=t<0?tell*1.1:burst*(1.35-0.65*smooth(0.12,0.56,t));
    const uint8_t *alpha_data=alpha.ptr();
    const float *samples=emission.ptr();
    for (int y=0;y<h_;++y) {
        const int iy=int(std::floor((y-double(origin.y))/cell));
        const double dy=y-double(source.y);
        for (int x=0;x<w_;++x) {
            const int ix=int(std::floor((x-double(origin.x))/cell));
            const double shadow=ix>=0 && ix<width && iy>=0 && iy<height?alpha_data[iy*width+ix]/255.0:0;
            const double visible=1-shadow,dx=x-double(source.x),distance=std::sqrt(dx*dx+dy*dy)/wl_;
            if (visible<0.01 || distance>range_end) continue;
            const double falloff=(1-smooth(range_end*0.8,range_end,distance))/(1+std::pow(distance/420,2)),strength=visible*gain*falloff;
            if (!front) {reference_add(x,y,tint,strength*(tell*0.22+burst*0.25));continue;}
            if (burst>0) {
                const double angle=std::atan2(dy,dx),ray=0.45+0.55*std::pow(0.5+0.5*std::sin(angle*23+std::sin(angle*7)*2.3),3);
                reference_add(x,y,flash,strength*burst*ray*0.55*(1-smooth(0,range_end,distance)*0.5));
            }
            const int tx=int(std::floor(96+dx*96/(aperture*stretch))),ty=int(std::floor(96+dy*96/aperture));
            if (tx>=0 && tx<192 && ty>=0 && ty<192) {
                const double flux=double(samples[ty*192+tx])*visible*gain;
                reference_add(x,y,corona,flux*exposure*0.8);
                reference_add(x,y,hot,flux*flux*exposure);
            }
        }
    }
}




// 炎の動的な3層密度場。領域の保存場所を再利用し、累積順と float32 の丸めは元と揃える。




void SpeedFxRaster::reference_beam(Vector2 a,Vector2 b,PackedColorArray palette,Dictionary settings) {
    const double fade=settings.get("fade",1),light_strength=settings.get("light_strength",1);
    const Vector2 delta=b-a;
    const double length=delta.length();
    if (length<1 || palette.size()<5) return;
    const Vector2 direction=delta/length,normal(-direction.y,direction.x);
    const double time=settings.get("time",0),alpha=clamp1(double(settings.get("alpha",1))),width=settings["w"],d0=double(settings.get("from",0))*length,d1=double(settings.get("to",1))*length,taper=settings.get("taper",0),intensity=settings.get("intensity",1);
    const bool rounded=settings.get("round",false);
    for (double d=d0;d<=d1;d+=0.5) {
        double ends;
        if (taper!=0) ends=std::pow(std::min({1.0,(d-d0)/taper*(d0>0?1:3),(d1-d)/taper}),0.8);
        else if (rounded) ends=std::min(1.0,std::sqrt(std::max(0.0,std::min(d,length-d))/(width*0.9+0.01)));
        else ends=std::min(1.0,(d+2)/4);
        const double w=width*(1+0.1*std::sin(d*0.35-time*40))*ends,cycle=d*0.03-time*3;
        const int pulse=cycle-std::floor(cycle)<0.06?1:0;
        const Vector2 point=a+direction*d;
        for (double q0=-w*1.25;q0<=w*1.25;q0+=0.5) {
            const double q=std::abs(q0)/std::max(w,0.01);
            const int level=std::max(0,(q<0.25?0:q<0.45?1:q<0.7?2:q<0.95?3:4)-pulse);
            const Vector2 pixel=point+normal*q0;
            reference_dot(pixel,palette[4-level],alpha*(level==4?0.45:1),fade);
        }
        if ((int(std::floor(d*2+0.5))&5)==0) reference_light(point,palette[2],0.25*alpha*intensity*fade*light_strength);
    }
    reference_glow_line(a+direction*d0,a+direction*d1,width*2.6+3,palette[2],0.35*alpha*intensity,fade,light_strength);
}



void SpeedFxRaster::corona_selection(Vector2 from,Vector2 to,double charge,double radius,double intensity,PackedColorArray palette,double clock) {
    if (palette.size()<5) return;
    const Vector2 delta=to-from,normal=Vector2(-delta.y,delta.x)/std::max(double(delta.length()),0.000001);
    for (int i=0;i<14;++i) {
        const double f=Math::fposmod(hash1(i*3.1)+clock*2.6,1.0),wave=(hash1(i*7.7)-0.5)*10*std::sin(PI*f);
        const Vector2 point=from+delta*f+normal*wave;
        reference_dot(point.x,point.y,palette[f>0.7?4:3],charge*(0.4+0.6*f));
    }
    reference_glow(to,radius,palette[2],0.4*charge*intensity);
}
void SpeedFxRaster::corona_trail(Vector2 center,Vector2 direction,double trail,double age,double clock,double seed_angle,PackedColorArray palette) {
    if (palette.size()<8) return;
    const Vector2 normal(-direction.y,direction.x);
    const int64_t frame=int64_t(std::floor(clock*30)),noise_seed=int64_t(seed_angle*9);
    const auto random=[&](int64_t x,int64_t y) {return double(reference_hash({x,y,noise_seed}))/4294967296.0;};
    const auto noise=[&](double x,double y) {
        const int64_t ix=int64_t(std::floor(x)),iy=int64_t(std::floor(y));
        const double fx=x-ix,fy=y-iy,ux=fx*fx*(3-2*fx),uy=fy*fy*(3-2*fy);
        return mix1(mix1(random(ix,iy),random(ix+1,iy),ux),mix1(random(ix,iy+1),random(ix+1,iy+1),ux),uy)*2-1;
    };
    for (double d=0;d<=trail;d+=0.5) {
        const double q=d/std::max(trail,1.0),heat=1-std::pow(d/std::max(trail,1.0),0.8)+noise(d*0.12-clock*40,3)*0.12;
        const double width=(0.6+2.6*std::pow(1-std::min(1.0,q/0.35),1.4))*(q<0.35?1:0.5);
        const Vector2 point=center-direction*d;
        if (q>0.55 && hash1(std::floor(d/3)*7.1+frame)<(q-0.55)*1.6) continue;
        for (double w=-width;w<=width;w+=0.5) {
            const double edge=std::abs(w)/std::max(width,0.01);
            const int level=edge<0.38?(heat>0.8?7:heat>0.6?6:heat>0.42?4:heat>0.25?3:2):(heat>0.6?5:heat>0.35?3:2);
            const Vector2 at=point+normal*w;
            reference_dot(at.x,at.y,palette[level],q<0.85?1:(1-q)/0.15);
        }
    }
    reference_glow_line(center,center-direction*trail*0.45,6,palette[4],0.35);
    reference_glow_line(center,center-direction*trail*0.2,3,palette[7],0.3);
    const int64_t seed=int64_t(23+seed_angle*10);
    for (int i=0;i<16;++i) {
        ReferenceRng g(reference_hash({seed,i,911}));
        const double born=g.next()*0.4,lifetime=g.between(0.1,0.28);
        for (double elapsed=Math::fposmod(age-born,0.4);elapsed<lifetime;elapsed+=0.4) {
            ReferenceRng r(reference_hash({seed,i}));
            const double k=elapsed/lifetime,back=r.between(4,trail*0.5),side=r.between(-1,1)*30*elapsed;
            const Vector2 point=center-direction*(back+40*elapsed*wl_)+normal*side,start=point+direction*2;
            int x=int(std::floor(start.x)),y=int(std::floor(start.y));
            const int end_x=int(std::floor(point.x)),end_y=int(std::floor(point.y)),dx=std::abs(end_x-x),dy=-std::abs(end_y-y),sx=x<end_x?1:-1,sy=y<end_y?1:-1,n=std::max({1,dx,-dy});
            int err=dx+dy,step=0;
            while (true) {
                const double u=double(step)/n;
                reference_dot(x,y,palette[u>0.5?7:4],1-k);
                ++step;
                if (x==end_x && y==end_y) break;
                const int e2=2*err;
                if (e2>=dy) {err+=dy;x+=sx;}
                if (e2<=dx) {err+=dx;y+=sy;}
            }
        }
    }
}

}
