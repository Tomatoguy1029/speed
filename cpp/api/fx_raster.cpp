#include "fx_raster.h"
#include <algorithm>
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
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
Color hexc(uint32_t v) {return Color(((v>>16)&255)/255.0f,((v>>8)&255)/255.0f,(v&255)/255.0f);}
const Color FLAME[9]={hexc(0xffffff),hexc(0xfbf4ff),hexc(0xe6d8ff),hexc(0xc9b0ff),hexc(0xa884ff),hexc(0x8259ee),hexc(0x5f3cc8),hexc(0x412a94),hexc(0x291c62)};
const Color DARK[8]={hexc(0xf4e2ff),hexc(0xd39bff),hexc(0x9a4cf0),hexc(0x6a24c4),hexc(0x3e1484),hexc(0x220b50),hexc(0x110630),hexc(0x070214)};
const Color PINK=hexc(0xff5fd2),CYAN=hexc(0x58d8ff),VIOLET=hexc(0x8a5cff);
const double LAYERS[4][3]={{1,1,6},{0.76,0.86,4},{0.54,0.68,2},{0.3,0.42,0}};
const double BACK_LAYERS[4][3]={{1,1,7},{0.76,0.86,5},{0.54,0.68,3},{0.3,0.42,2}};
const double COOL_LAYERS[3][3]={{1,1,7},{0.72,0.82,6},{0.44,0.58,5}};
Color cmix(Color a,Color b,double k) {return a.lerp(b,float(k));}
// fxlib.js の FX.ramp：主色から暗→明の5段。
struct Ramp {Color v[5];explicit Ramp(Color c) {const auto mk=[&](double l,double w) {return Color(float(std::min(1.0,c.r*l+w*(1-c.r*l))),float(std::min(1.0,c.g*l+w*(1-c.g*l))),float(std::min(1.0,c.b*l+w*(1-c.b*l))));};v[0]=mk(0.35,0);v[1]=mk(0.6,0);v[2]=mk(1,0);v[3]=mk(1,0.45);v[4]=Color(1,1,1);}};
}
void SpeedFxRaster::_bind_methods() {
    ClassDB::bind_method(D_METHOD("begin","colors","lights","width","height","world_scale","camera"),&SpeedFxRaster::begin);
    ClassDB::bind_method(D_METHOD("take_colors"),&SpeedFxRaster::take_colors);
    ClassDB::bind_method(D_METHOD("take_lights"),&SpeedFxRaster::take_lights);
    ClassDB::bind_method(D_METHOD("dim","amount","flash"),&SpeedFxRaster::dim);
    ClassDB::bind_method(D_METHOD("breath","fan","elapsed","active","axis","sweep","half_angle","reach","fan_angle"),&SpeedFxRaster::breath);
    ClassDB::bind_method(D_METHOD("light_mask_reset"),&SpeedFxRaster::light_mask_reset);
    ClassDB::bind_method(D_METHOD("light_mask","mouth","pull","head","head_reach","axis","sweep","half_angle","reach","rocks","radius","strength"),&SpeedFxRaster::light_mask);
    ClassDB::bind_method(D_METHOD("exhale","at","angle","reach","width","beam_age","extend","life","time"),&SpeedFxRaster::exhale);
    ClassDB::bind_method(D_METHOD("comet","pos","angle","age","speed","radius","tail","shine","seed","with_star"),&SpeedFxRaster::comet);
    ClassDB::bind_method(D_METHOD("dark_shot","pos","angle","age","seed"),&SpeedFxRaster::dark_shot);
}
void SpeedFxRaster::begin(PackedByteArray colors,PackedByteArray lights,int width,int height,double world_scale,Vector2 camera) {colors_=colors;lights_=lights;w_=width;h_=height;wl_=world_scale;camera_=camera;c_=colors_.ptrw();l_=lights_.ptrw();}
PackedByteArray SpeedFxRaster::take_colors() {PackedByteArray out=colors_;colors_=PackedByteArray();c_=nullptr;return out;}
PackedByteArray SpeedFxRaster::take_lights() {PackedByteArray out=lights_;lights_=PackedByteArray();l_=nullptr;return out;}
void SpeedFxRaster::put(int x,int y,Color c) {if (x<0 || y<0 || x>=w_ || y>=h_) return;uint8_t *q=c_+(y*w_+x)*4;q[0]=uint8_t(c.r*255);q[1]=uint8_t(c.g*255);q[2]=uint8_t(c.b*255);q[3]=255;}
void SpeedFxRaster::blend(float x,float y,Color c,double a) {if (a<=0.004) return;const int ix=int(std::floor(x)),iy=int(std::floor(y));if (ix<0 || iy<0 || ix>=w_ || iy>=h_) return;a=std::min(a,1.0);uint8_t *q=c_+(iy*w_+ix)*4;const double da=q[3]/255.0,oa=a+da*(1-a),k=a/oa;q[0]=uint8_t(int(c.r*255)*k+q[0]*(1-k));q[1]=uint8_t(int(c.g*255)*k+q[1]*(1-k));q[2]=uint8_t(int(c.b*255)*k+q[2]*(1-k));q[3]=uint8_t(oa*255);}
void SpeedFxRaster::add(int x,int y,Color c,double k) {if (k<=0.004 || x<0 || y<0 || x>=w_ || y>=h_) return;uint8_t *q=l_+(y*w_+x)*4;q[0]=uint8_t(std::min(255.0,q[0]+int(c.r*255)*k));q[1]=uint8_t(std::min(255.0,q[1]+int(c.g*255)*k));q[2]=uint8_t(std::min(255.0,q[2]+int(c.b*255)*k));}
void SpeedFxRaster::glow(float x,float y,float r,Color c,double strength) {if (r<1 || strength<=0.004) return;for (int sy=std::max(0,int(std::floor(y-r)));sy<=std::min(h_-1,int(std::ceil(y+r)));++sy) for (int sx=std::max(0,int(std::floor(x-r)));sx<=std::min(w_-1,int(std::ceil(x+r)));++sx) {const double d=std::hypot(sx+0.5-x,sy+0.5-y)/r;if (d<1) add(sx,sy,c,(1-d)*(1-d)*strength);}}
void SpeedFxRaster::disc(float cx,float cy,float r,Color c,double a) {const float r2=r*r;for (int sy=int(std::floor(cy-r));sy<=int(std::ceil(cy+r));++sy) {const float dy=sy+0.5f-cy,s2=r2-dy*dy;if (s2<0) continue;const float s=std::sqrt(s2);for (int sx=int(std::ceil(cx-s-0.5f));sx<=int(std::floor(cx+s-0.5f));++sx) {if (a>=1) put(sx,sy,c);else blend(sx,sy,c,a);}}}
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
}
