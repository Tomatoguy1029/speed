#include "pixel_fx.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>
#include <limits>
#include <vector>
#include <godot_cpp/core/class_db.hpp>
// 元: pixelfx 0.3.0 core/painter.js・core/sim.js・core/color.js・core/math.js・core/fx.js、
// fx/explosions/firework-burst.js、fx/ui/confetti.js（MIT, Copyright (c) 2026 Patch / Hugo Duprez）。
// 乱数の取り出し順も元と同じにする（C++の引数の評価順に頼らず、先に変数へ取る）。
namespace godot {
namespace {
using C32=uint32_t;
constexpr double PI=3.141592653589793,TAU=PI*2,INF=std::numeric_limits<double>::infinity();
double clamp01(double x) {return x<0?0:x>1?1:x;}
double seg(double t,double t0,double t1) {return clamp01((t-t0)/(t1-t0));}
double out_cubic(double t) {return 1-std::pow(1-t,3);}
int trunc_int(double v) {return int(v);}
C32 rgb(double r,double g,double b) {return (255u<<24)|((uint32_t(trunc_int(b))&255u)<<16)|((uint32_t(trunc_int(g))&255u)<<8)|(uint32_t(trunc_int(r))&255u);}
int red(C32 c) {return c&255;}
int green(C32 c) {return (c>>8)&255;}
int blue(C32 c) {return (c>>16)&255;}
C32 hexv(uint32_t v) {return rgb((v>>16)&255,(v>>8)&255,v&255);}
C32 from_color(Color c) {return rgb(std::lround(c.r*255.0),std::lround(c.g*255.0),std::lround(c.b*255.0));}
C32 mix(C32 a,C32 b,double t) {t=clamp01(t);return rgb(red(a)+(red(b)-red(a))*t,green(a)+(green(b)-green(a))*t,blue(a)+(blue(b)-blue(a))*t);}
C32 scale(C32 c,double k) {return rgb(std::min(255.0,red(c)*k),std::min(255.0,green(c)*k),std::min(255.0,blue(c)*k));}
const C32 WHITE=hexv(0xffffff);
const double BAYER[16]={0.5/16,8.5/16,2.5/16,10.5/16,12.5/16,4.5/16,14.5/16,6.5/16,3.5/16,11.5/16,1.5/16,9.5/16,15.5/16,7.5/16,13.5/16,5.5/16};
const int CROSS[4][2]={{1,0},{-1,0},{0,1},{0,-1}},DIAG[4][2]={{1,1},{1,-1},{-1,1},{-1,-1}};
const C32 SMOKE_RAMP[5]={hexv(0x7b6f72),hexv(0x5d5660),hexv(0x433d48),hexv(0x2b2630),hexv(0x1a171e)};
C32 ramp_at(const C32 *r,int n,double t) {return r[std::min(n-1,std::max(0,int(std::floor(t*n))))];}

struct Rng {
    uint32_t s;
    explicit Rng(uint32_t seed=1):s(seed?seed:1) {}
    double next() {uint32_t t=(s+=0x6d2b79f5u);t=(t^(t>>15))*(t|1u);t^=t+(t^(t>>7))*(t|61u);return double(t^(t>>14))/4294967296.0;}
    double range(double a,double b) {return a+(b-a)*next();}
    bool chance(double p) {return next()<p;}
};

struct Frame {int w=0,h=0,ox=0,oy=0;std::vector<C32> C,L;};

struct Painter {
    Frame *f;
    double tx=0,ty=0,fx=1,cs=1,sn=0,fade=1,light_k=1;
    explicit Painter(Frame *frame):f(frame) {}
    void place(double x,double y,bool flip=false,double angle=0) {tx=x;ty=y;fx=flip?-1:1;cs=std::cos(angle);sn=std::sin(angle);}
    double to_x(double x,double y) const {return tx+x*fx*cs-y*sn;}
    double to_y(double x,double y) const {return ty+x*fx*sn+y*cs;}
    double from_x(double sx,double sy) const {const double dx=sx-tx,dy=sy-ty;return (dx*cs+dy*sn)*fx;}
    double from_y(double sx,double sy) const {const double dx=sx-tx,dy=sy-ty;return -dx*sn+dy*cs;}
    int cell_x(double x,double y) const {return int(std::floor(to_x(std::floor(x)+0.5,std::floor(y)+0.5)));}
    int cell_y(double x,double y) const {return int(std::floor(to_y(std::floor(x)+0.5,std::floor(y)+0.5)));}
    void put(int sx,int sy,C32 c,double a=1) {
        if (!c) return;
        a*=fade;
        if (a<1 && a<=BAYER[((sy&3)<<2)|(sx&3)]) return;
        const int x=sx-f->ox,y=sy-f->oy;
        if (x<0 || y<0 || x>=f->w || y>=f->h) return;
        f->C[y*f->w+x]=c;
    }
    void add(int sx,int sy,C32 c,double k=1) {
        k*=fade*light_k;
        if (k<=0.004) return;
        const int x=sx-f->ox,y=sy-f->oy;
        if (x<0 || y<0 || x>=f->w || y>=f->h) return;
        const int i=y*f->w+x;const C32 d=f->L[i];
        const int r=int(std::min(255.0,(d&255)+(c&255)*k)),g=int(std::min(255.0,((d>>8)&255)+((c>>8)&255)*k)),b=int(std::min(255.0,((d>>16)&255)+((c>>16)&255)*k));
        f->L[i]=(255u<<24)|(uint32_t(b)<<16)|(uint32_t(g)<<8)|uint32_t(r);
    }
    void blend_px(int sx,int sy,C32 c,double a) {
        a*=fade;
        if (!c || a<=0.004) return;
        const int x=sx-f->ox,y=sy-f->oy;
        if (x<0 || y<0 || x>=f->w || y>=f->h) return;
        const int i=y*f->w+x;const C32 d=f->C[i];
        const double da=(d>>24)/255.0,oa=a+da*(1-a),k=a/oa;
        const auto ch=[&](int s) {return uint32_t(trunc_int(((c>>s)&255)*k+((d>>s)&255)*(1-k)))&255u;};
        f->C[i]=((uint32_t(trunc_int(oa*255))&255u)<<24)|(ch(16)<<16)|(ch(8)<<8)|ch(0);
    }
    void blend(double x,double y,C32 c,double a) {blend_px(cell_x(x,y),cell_y(x,y),c,a);}
    void px(double x,double y,C32 c) {put(cell_x(x,y),cell_y(x,y),c,1);}
    void dot(double x,double y,C32 c,double a=1) {if (a>0) put(cell_x(x,y),cell_y(x,y),c,a);}
    template<class F> void each(double x0,double y0,double x1,double y1,F fn) {
        double ax=INF,bx=-INF,ay=INF,by=-INF;
        for (int k=0;k<4;++k) {const double x=k&1?x1:x0,y=k&2?y1:y0,sx=to_x(x,y),sy=to_y(x,y);ax=std::min(ax,sx);bx=std::max(bx,sx);ay=std::min(ay,sy);by=std::max(by,sy);}
        const int sx0=std::max(int(std::floor(ax)),f->ox),sx1=std::min(int(std::ceil(bx)),f->ox+f->w-1);
        const int sy0=std::max(int(std::floor(ay)),f->oy),sy1=std::min(int(std::ceil(by)),f->oy+f->h-1);
        for (int sy=sy0;sy<=sy1;++sy) for (int sx=sx0;sx<=sx1;++sx) {const double cx=sx+0.5,cy=sy+0.5;fn(from_x(cx,cy),from_y(cx,cy),sx,sy);}
    }
    struct Out {C32 c;double a;C32 l;double k;};
    template<class F> void shade(double x0,double y0,double x1,double y1,F fn) {
        each(x0,y0,x1,y1,[&](double lx,double ly,int sx,int sy) {
            Out o{0,1,0,0};
            C32 c=fn(lx,ly,o);if (!c) c=o.c;
            if (c) put(sx,sy,c,o.a);
            if (o.k>0) add(sx,sy,o.l?o.l:c,o.k);
        });
    }
    template<class FC,class FA> void line_fn(double x0,double y0,double x1,double y1,FC color,FA alpha) {
        int sx=cell_x(x0,y0),sy=cell_y(x0,y0);
        const int ex=cell_x(x1,y1),ey=cell_y(x1,y1);
        const int dx=std::abs(ex-sx),dy=-std::abs(ey-sy),stepx=sx<ex?1:-1,stepy=sy<ey?1:-1;
        int n=std::max(dx,-dy);if (!n) n=1;
        int err=dx+dy,i=0;
        for (;;) {
            const double u=double(i++)/n;
            put(sx,sy,color(u),alpha(u));
            if (sx==ex && sy==ey) break;
            const int e2=2*err;
            if (e2>=dy) {err+=dy;sx+=stepx;}
            if (e2<=dx) {err+=dx;sy+=stepy;}
        }
    }
    void line(double x0,double y0,double x1,double y1,C32 c,double a=1) {line_fn(x0,y0,x1,y1,[c](double) {return c;},[a](double) {return a;});}
    void glow(double x,double y,double r,C32 c,double k=0.5) {
        if (r<1 || k<=0.004) return;
        const double cx=to_x(x,y),cy=to_y(x,y);
        const int x0=int(std::floor(cx-r)),x1=int(std::ceil(cx+r)),y0=int(std::floor(cy-r)),y1=int(std::ceil(cy+r));
        for (int sy=y0;sy<=y1;++sy) {
            const double dy=(sy+0.5-cy)/r;
            for (int sx=x0;sx<=x1;++sx) {const double dx=(sx+0.5-cx)/r,d=dx*dx+dy*dy;if (d>=1) continue;const double q=1-std::sqrt(d);add(sx,sy,c,q*q*k);}
        }
    }
    void circle(double cx,double cy,double r,C32 c,double a=1) {
        if (r<0.6) {dot(cx,cy,c,a);return;}
        shade(cx-r,cy-r,cx+r,cy+r,[&](double x,double y,Out &o)->C32 {const double dx=x-cx,dy=y-cy;if (dx*dx+dy*dy>r*r) return 0;o.c=c;o.a=a;return 0;});
    }
    void disc(double cx,double cy,double r,C32 c,double a) {
        if (r<0.5) {blend(cx,cy,c,a);return;}
        each(cx-r,cy-r,cx+r,cy+r,[&](double x,double y,int sx,int sy) {const double dx=x-cx,dy=y-cy;if (dx*dx+dy*dy>r*r) return;blend_px(sx,sy,c,a);});
    }
};

int js_round(double v) {return int(std::floor(v+0.5));}
void sparkle(Painter &p,double x,double y,double arm,C32 c,C32 tip,double k) {
    const int n=js_round(arm);
    if (n<1) return;
    const int X=int(std::floor(x)),Y=int(std::floor(y));
    for (int d=1;d<=n;++d) {const C32 cc=d>n*0.6?tip:c;for (const auto &q:CROSS) p.px(X+q[0]*d,Y+q[1]*d,cc);}
    if (n>=3) for (const auto &q:DIAG) p.px(X+q[0],Y+q[1],c);
    if (n>=6) for (const auto &q:DIAG) p.px(X+q[0]*2,Y+q[1]*2,tip);
    p.px(X,Y,WHITE);
    p.glow(x,y,4+n*2,c,k);
}

enum Kind {SPARK=0,MOTE=1,STREAK=2,FLAKE=3,VAPOUR=4,DUST=5,STAR=6,EMBER=7,SMOKE=8,FIRE=9,BRAND=10,GRIT=11};
constexpr int PF_BIG=2,PF_BACK=4;
bool soft_kind(int k) {return k==VAPOUR || k==DUST || k==SMOKE;}
enum Layer {BOTH,BACK,FRONT};

struct Particles {
    struct Q {int k;double x,y,vx,vy,life,max;C32 col;double size,seed,delay;int flag;};
    Rng *R;
    std::vector<Q> list;
    double t=0,ground=INF;
    std::vector<C32> sparks;
    Particles(Rng *rng,std::vector<C32> s,double g=INF):R(rng),ground(g),sparks(std::move(s)) {}
    void spawn(int k,double x,double y,double vx,double vy,double life,C32 col=WHITE,double size=1,double delay=0,int flag=0) {
        const double seed=R->next()*100;
        list.push_back({k,x,y,vx,vy,life,life,col,size,seed,delay,flag});
    }
    void update(double dt) {
        t+=dt;
        for (int i=int(list.size())-1;i>=0;--i) {
            Q &p=list[i];
            if (p.delay>0) {p.delay-=dt;continue;}
            if ((p.life-=dt)<=0) {list.erase(list.begin()+i);continue;}
            switch (p.k) {
                case SPARK: {
                    p.vy+=950*0.45*dt;p.vx-=p.vx*2.2*dt;p.vy-=p.vy*2.2*dt;
                    const double g=ground,ny=p.y+p.vy*dt;
                    p.x+=p.vx*dt;
                    if (p.vy>0 && p.y<=g && ny>=g) {p.vy=-p.vy*0.45;p.vx*=0.7;p.y=g-0.25;}
                    else p.y=ny;
                    continue;
                }
                case SMOKE: {
                    const bool big=p.flag&PF_BIG;
                    p.vy-=(big?23:16)*dt;p.vx+=std::sin(t*1.3+p.seed)*8*dt;p.vx-=p.vx*1.6*dt;p.vy-=p.vy*1.2*dt;
                    break;
                }
                default: {
                    const double drag=soft_kind(p.k)?4:1.6;
                    p.vx-=p.vx*drag*dt;p.vy-=p.vy*drag*dt+5*dt;
                }
            }
            p.x+=p.vx*dt;p.y+=p.vy*dt;
        }
    }
    void draw(Painter &p,Layer layer) {
        for (const Q &q:list) {
            if (q.delay>0) continue;
            if (layer!=BOTH && ((soft_kind(q.k) || (q.flag&PF_BACK))?BACK:FRONT)!=layer) continue;
            const double k=q.life/q.max,x=q.x,y=q.y;double sp=std::hypot(q.vx,q.vy);if (!sp) sp=1;
            const double ux=q.vx/sp,uy=q.vy/sp;
            switch (q.k) {
                case SPARK: {
                    const auto &S=sparks;const C32 head=k>0.6?S[0]:k>0.3?S[1]:S[2];const double len=std::min(9.0,1+sp*0.022);
                    p.line(x-ux*len,y-uy*len,x-ux*len*0.4,y-uy*len*0.4,k>0.5?head:S.back());
                    p.line(x-ux*len*0.45,y-uy*len*0.45,x,y,head);
                    p.glow(x,y,3,head,0.45*k);
                    break;
                }
                case VAPOUR: {
                    const double r=q.size*(0.6+(1-k)*0.9);
                    p.disc(x,y,r,q.col,std::pow(k,1.3)*0.45);
                    break;
                }
                case SMOKE: {
                    const double age=1-k;const bool big=q.flag&PF_BIG;
                    const double r=q.size*(0.65+std::min(1.0,age*2.5)*0.45+age*(big?0.5:0.4));
                    const double a=std::min(1.0,age*12)*std::min(1.0,k*2.4)*(big?0.7:0.58);
                    const C32 c=q.col?mix(q.col,ramp_at(SMOKE_RAMP,5,age),age):ramp_at(SMOKE_RAMP,5,age*1.05);
                    p.disc(x,y,r,c,a*0.45);
                    p.disc(x+r*0.05,y+r*0.06,r*0.74,c,a*0.62);
                    if (age<0.5) p.disc(x-r*0.22,y-r*0.3,r*0.5,mix(c,WHITE,0.12),a*0.4*(1-age*2));
                    break;
                }
                default: {
                    const double tw=0.6+0.4*std::sin(t*(8+std::fmod(q.seed,5.0))+q.seed);
                    if (q.size<1) {
                        if (tw*k>0.25) p.px(x,y,tw>0.8?WHITE:q.col);
                        p.glow(x,y,3,q.col,0.4*k*tw);
                        break;
                    }
                    sparkle(p,x,y,q.size*tw*std::min(1.0,k*3),q.col,scale(q.col,0.75),0.5*k*tw);
                }
            }
        }
    }
};

struct Lights {
    struct L {double x,y,r;C32 c;double k,life,max;};
    std::vector<L> list;
    void add(double x,double y,double r,C32 c,double k,double life) {list.push_back({x,y,r,c,k,life,life});}
    void update(double dt) {for (int i=int(list.size())-1;i>=0;--i) if ((list[i].life-=dt)<=0) list.erase(list.begin()+i);}
    void draw(Painter &p) {for (const L &l:list) {const double k=l.life/l.max;p.glow(l.x,l.y,l.r*(0.55+0.45*k),l.c,l.k*k*k);}}
};

struct Effect {
    virtual ~Effect()=default;
    virtual void update(double dt)=0;
    virtual void draw_back(Painter &p)=0;
    virtual void draw(Painter &p)=0;
};

// fx/explosions/firework-burst.js
struct Firework : Effect {
    static constexpr double RISE=0.42,Y0=72,DRAG=2.6,G=88,TRAIL=0.34,TURN=0.22;
    struct S {double x,y,vx,vy,life,age;const C32 *ramp,*first;bool big;std::vector<double> pts;double acc,seed;};
    struct Pop {double x,y,t0,life;C32 c;};
    C32 C[7],K[7];
    Rng R;
    Particles ps;
    Lights lights;
    std::vector<S> stars;
    std::vector<Pop> pops;
    double t=0;bool burst=false;
    Firework(const C32 *palette,const C32 *core,uint32_t seed):R(seed),ps(&R,{}) {
        std::copy(palette,palette+7,C);std::copy(core,core+7,K);
        ps.sparks={K[6],K[5],K[4],K[3]};
    }
    void shell(int n,double speed,const C32 *ramp,double l0,double l1,const C32 *first) {
        for (int i=0;i<n;++i) {
            const double z=R.range(-1,1),a=R.range(0,TAU),s=std::sqrt(1-z*z),v=speed*R.range(0.93,1.05);
            const double life=R.range(l0,l1);const bool big=R.chance(0.2);const double acc=R.next(),seed=R.range(0,100);
            stars.push_back({0,0,std::cos(a)*s*v,std::sin(a)*s*v,life,0,ramp,first,big,{},acc,seed});
        }
    }
    void update(double dt) override {
        t+=dt;
        if (t<RISE) {
            const double y=Y0*(1-out_cubic(t/RISE));
            if (R.chance(50*dt)) {const double x=R.range(-0.5,0.5),vx=R.range(-25,25),vy=R.range(20,70),life=R.range(0.15,0.35);ps.spawn(SPARK,x,y+2,vx,vy,life);}
            if (R.chance(14*dt)) {const double x=R.range(-1,1),vx=R.range(-3,3),vy=R.range(5,15),life=R.range(0.5,0.8),size=R.range(1.5,2.5);ps.spawn(VAPOUR,x,y+3,vx,vy,life,hexv(0x4a4458),size);}
        }
        if (!burst && t>=RISE) {
            burst=true;
            lights.add(0,0,110,C[4],0.6,1.5);
            lights.add(0,0,30,WHITE,0.5,0.07);
            shell(66,236,C,1.35,1.9,K);
            shell(26,120,K,1.0,1.4,K);
            for (int i=0;i<7;++i) {const double a=R.range(0,TAU),d=R.range(0,8),v1=R.range(10,30),v2=R.range(10,30),life=R.range(2.2,3),size=R.range(6,11);ps.spawn(VAPOUR,std::cos(a)*d,std::sin(a)*d,std::cos(a)*v1,std::sin(a)*v2,life,hexv(0x4a4458),size);}
            for (int i=0;i<24;++i) {const double a=R.range(0,TAU),sp=R.range(40,140),life=R.range(0.15,0.35);ps.spawn(SPARK,0,0,std::cos(a)*sp,std::sin(a)*sp,life);}
        }
        for (int i=int(stars.size())-1;i>=0;--i) {
            S &s=stars[i];
            s.age+=dt;
            const double k=s.age/s.life;
            if (k>=1) {
                for (int j=0;j<2+(s.big?1:0);++j) {const double x=s.x+R.range(-3,3),y=s.y+R.range(-3,3),t0=t+R.range(0,0.18),life=R.range(0.06,0.12);const C32 c=R.chance(0.6)?WHITE:s.ramp[5];pops.push_back({x,y,t0,life,c});}
                stars.erase(stars.begin()+i);
                continue;
            }
            s.vx-=s.vx*DRAG*dt;s.vy-=s.vy*DRAG*dt-G*dt;s.x+=s.vx*dt;s.y+=s.vy*dt;
            s.pts.push_back(s.x);s.pts.push_back(s.y);s.pts.push_back(t);
            while (s.pts.size()>3 && t-s.pts[2]>TRAIL) s.pts.erase(s.pts.begin(),s.pts.begin()+3);
            for (s.acc+=dt*(k<0.25?4:11);s.acc>1;s.acc--) {
                const double vx=s.vx*0.15+R.range(-6,6),vy=s.vy*0.15+R.range(0,10),life=R.range(0.35,0.8);const C32 c=R.chance(0.5)?K[5]:WHITE;const double size=R.chance(0.15)?R.range(1,1.6):0.5;
                ps.spawn(STAR,s.x,s.y,vx,vy,life,c,size);
            }
        }
        for (int i=int(pops.size())-1;i>=0;--i) if (t>pops[i].t0+pops[i].life) pops.erase(pops.begin()+i);
        ps.update(dt);
        lights.update(dt);
    }
    void draw_back(Painter &p) override {ps.draw(p,BACK);}
    void flare_rays(Painter &p,double x,double y,double L,double ang) {
        if (L<1) return;
        for (int i=0;i<8;++i) {
            const bool diag=i%2==1;const double an=ang+i*TAU/8,len=diag?L*0.42:L,ca=std::cos(an),sa=std::sin(an);
            for (double d=0;d<=len;d+=0.5) {const double u=d/len;p.dot(x+ca*d,y+sa*d,diag?(u<0.5?K[5]:K[4]):u<0.3?WHITE:u<0.65?C[5]:C[4],u<0.7?1:1-(u-0.7)/0.35);}
        }
        p.glow(x,y,4+L*1.2,C[4],0.3);
        p.glow(x,y,2+L*0.3,WHITE,0.25);
    }
    void draw(Painter &p) override {
        if (t<RISE) {
            const double u=t/RISE,y=Y0*(1-out_cubic(u));
            const C32 k5=K[5],k3=K[3];
            p.line_fn(0,y,0,y+3+6*(1-u),[&](double q) {return q<0.3?k5:k3;},[](double) {return 1.0;});
            p.px(0,y,WHITE);
            p.glow(0,y,7,K[4],0.5);
        }
        for (const S &s:stars) {
            const double k=s.age/s.life;const auto &P2=s.pts;const int n=int(P2.size()/3);
            for (int j=n-1;j>0;--j) {
                const double u=(t-P2[j*3+2])/TRAIL;
                if (u>=1) break;
                const C32 *ramp=s.age-(t-P2[j*3+2])<TURN?s.first:s.ramp;
                const C32 c=u<0.3?ramp[5]:u<0.6?ramp[4]:ramp[3];
                p.line(P2[j*3],P2[j*3+1],P2[j*3-3],P2[j*3-2],c,std::pow(1-u,0.8)*(1.3-k*0.6));
            }
            if (k>0.72 && std::sin(t*60+s.seed)<-0.2) continue;
            const C32 *ramp=s.age<TURN?s.first:s.ramp;const C32 head=s.age<0.04?WHITE:k<0.55?ramp[s.age<TURN?5:6]:ramp[5];
            p.px(s.x,s.y,head);
            if (s.big && k<0.6 && s.age>0.06) for (const auto &q:CROSS) p.px(s.x+q[0],s.y+q[1],ramp[5]);
            p.glow(s.x,s.y,s.big?7:5,ramp[4],(s.big?0.7:0.5)*(1-k*0.6)*std::min(1.0,s.age/0.2));
        }
        for (const Pop &q:pops) {
            const double u=(t-q.t0)/q.life;
            if (u<0 || u>1) continue;
            sparkle(p,q.x,q.y,2.6*std::sin(PI*u),q.c,mix(q.c,C[3],0.5),0.5);
        }
        const double b=t-RISE;
        if (b>=0 && b<0.28) {
            const double u=b/0.28,L=32*std::pow(1-u,1.3);
            flare_rays(p,0,0,L,u*0.6);
            if (b<0.07) p.circle(0,0,2.6-b*20,WHITE);
        }
        ps.draw(p,FRONT);
        lights.draw(p);
    }
};

// fx/ui/confetti.js
struct Confetti : Effect {
    struct Popper {double x,y,a,t;};
    static constexpr Popper POPPERS[2]={{-74,-1,-PI/2+0.62,0.1},{74,-1,-PI/2-0.62,0.26}};
    struct Bit {double x,y,vx,vy;C32 c;double w,h,ang,spin,flip,fs,ph,amp,fw,x0;int mode;double rest,fall;};
    struct Ribbon {std::vector<std::pair<double,double>> pts;double vx,vy;C32 c;double ph,amp,fw;int mode;double x0,curl,fall;};
    C32 C[7];
    Rng R;
    Particles ps;
    Lights lights;
    std::vector<Bit> bits;
    std::vector<Ribbon> ribbons;
    bool fired[2]={false,false};
    double t=0,end=3.4-0.05;
    Confetti(const C32 *palette,uint32_t seed):R(seed),ps(&R,{hexv(0xffffff),hexv(0xfff3a6),hexv(0xffc23d),hexv(0xff8a2a)},0) {std::copy(palette,palette+7,C);}
    static double kick(double t,const Popper &pp) {return t<pp.t?0:3*std::exp(-(t-pp.t)*14);}
    C32 pick() {return C[int(std::floor(R.next()*7))];}
    void fire(const Popper &pp) {
        const double mx=pp.x+std::cos(pp.a)*11,my=pp.y+std::sin(pp.a)*11;
        lights.add(mx,my,34,WHITE,0.6,0.12);
        lights.add(mx,my,50,C[2],0.4,0.4);
        for (int i=0;i<6;++i) {const double v1=R.range(20,60),v2=R.range(-10,10),v3=R.range(20,60),life=R.range(0.6,1),size=R.range(2.5,4);ps.spawn(SMOKE,mx,my,std::cos(pp.a)*v1+v2,std::sin(pp.a)*v3,life,hexv(0x5d5660),size);}
        for (int i=0;i<12;++i) {const double an=pp.a+R.range(-0.5,0.5),sp=R.range(120,260),life=R.range(0.1,0.25);ps.spawn(SPARK,mx,my,std::cos(an)*sp,std::sin(an)*sp,life);}
        for (int i=0;i<46;++i) {
            const double an=pp.a+R.range(-0.38,0.38),sp=R.range(200,380);
            Bit b{};b.x=mx;b.y=my;b.vx=std::cos(an)*sp;b.vy=std::sin(an)*sp;
            b.c=pick();b.w=R.range(2,3);b.h=R.range(3,4.6);b.ang=R.range(0,TAU);b.spin=R.range(-14,14);b.flip=R.range(0,TAU);b.fs=R.range(5,13);b.ph=R.range(0,TAU);b.amp=R.range(5,12);b.fw=R.range(2,3.4);b.x0=0;b.mode=0;b.rest=0;b.fall=R.range(26,40);
            bits.push_back(b);
        }
        for (int i=0;i<4;++i) {
            const double an=pp.a+R.range(-0.25,0.25),sp=R.range(220,330);
            Ribbon r{};r.pts.assign(11,{mx,my});r.vx=std::cos(an)*sp;r.vy=std::sin(an)*sp;
            r.c=pick();r.ph=R.range(0,TAU);r.amp=R.range(6,12);r.fw=R.range(1.5,2.4);r.mode=0;r.x0=0;r.curl=R.range(0.7,1.1);r.fall=R.range(22,32);
            ribbons.push_back(r);
        }
    }
    void update(double dt) override {
        t+=dt;
        for (int i=0;i<2;++i) if (!fired[i] && t>=POPPERS[i].t) {fired[i]=true;fire(POPPERS[i]);}
        for (Bit &b:bits) {
            if (b.mode==2) {b.rest+=dt;continue;}
            b.flip+=b.fs*dt;
            if (b.mode==0) {
                b.vx-=b.vx*3.4*dt;b.vy-=b.vy*3.4*dt-140*dt;b.x+=b.vx*dt;b.y+=b.vy*dt;b.ang+=b.spin*dt;
                if (std::hypot(b.vx,b.vy)<40) {b.mode=1;b.x0=b.x-std::sin(b.ph)*b.amp;}
            } else {
                b.ph+=b.fw*dt;b.x0+=b.vx*dt;b.vx-=b.vx*2*dt;b.x=b.x0+std::sin(b.ph)*b.amp;
                b.y+=b.fall*(0.4+0.9*std::abs(std::cos(b.ph)))*dt;b.ang=std::cos(b.ph)*0.9;
                if (b.y>=-1) {b.y=-0.5;b.mode=2;b.ang=R.range(-0.3,0.3);b.flip=0;}
            }
        }
        for (Ribbon &r:ribbons) {
            auto &h=r.pts[0];
            if (r.mode==0) {
                r.vx-=r.vx*3*dt;r.vy-=r.vy*3*dt-120*dt;h.first+=r.vx*dt;h.second+=r.vy*dt;
                if (std::hypot(r.vx,r.vy)<35) {r.mode=1;r.x0=h.first-std::sin(r.ph)*r.amp;}
            } else if (h.second<-1) {
                r.ph+=r.fw*dt;r.x0+=r.vx*dt;r.vx-=r.vx*2*dt;h.first=r.x0+std::sin(r.ph)*r.amp;
                h.second+=r.fall*(0.5+0.7*std::abs(std::cos(r.ph)))*dt;
            }
            for (size_t i=1;i<r.pts.size();++i) {
                auto &a=r.pts[i-1];auto &b=r.pts[i];
                b.second=std::min(-0.5,b.second+20*dt);
                const double dx=b.first-a.first,dy=b.second-a.second;double d=std::hypot(dx,dy);if (!d) d=1;
                if (d>2.6) {b.first=a.first+dx/d*2.6;b.second=a.second+dy/d*2.6;}
            }
        }
        ps.update(dt);
        lights.update(dt);
    }
    void draw_back(Painter &p) override {ps.draw(p,BACK);}
    void popper(Painter &p,double x,double y,double a,double k,double alpha) {
        static const C32 INK=hexv(0x141019),PALE=hexv(0xc8c0d8);
        const double ca=std::cos(a),sa=std::sin(a),bx=x-ca*k,by=y-sa*k;
        const C32 c2=C[2],c2d=scale(C[2],0.75);
        p.shade(bx-12,by-12,bx+12,by+12,[&](double px,double py,Painter::Out &o)->C32 {
            const double dx=px-bx,dy=py-by,u=dx*ca+dy*sa,v=-dx*sa+dy*ca;
            if (u<0 || u>11) return 0;
            const double hw=0.8+u*0.32;
            if (std::abs(v)>hw+0.6) return 0;
            o.a=alpha;
            if (std::abs(v)>hw-0.4 || u>10.2 || u<0.8) return INK;
            const bool stripe=int(std::floor((u+v*0.6)/2.2))%2==0;
            return stripe?(v<0?c2:c2d):v<0?WHITE:PALE;
        });
    }
    void draw(Painter &p) override {
        const double fade=1-seg(t,end-0.45,end-0.05);
        for (const Popper &pp:POPPERS) {
            const double k=kick(t,pp);
            popper(p,pp.x,pp.y,pp.a,k,1-seg(t,2.5,2.9));
            const double ft=t-pp.t;
            if (ft>0 && ft<0.12) sparkle(p,pp.x+std::cos(pp.a)*13,pp.y+std::sin(pp.a)*13,7*(1-ft/0.12),WHITE,C[2],0.7);
        }
        for (const Ribbon &r:ribbons) {
            std::vector<std::pair<double,double>> pts(r.pts.size());
            for (size_t i=0;i<r.pts.size();++i) pts[i]={r.pts[i].first+std::sin(i*r.curl+t*9+r.ph)*(i?1.6:0),r.pts[i].second};
            for (size_t i=1;i<pts.size();++i) {
                const auto [x0,y0]=pts[i-1];const auto [x1,y1]=pts[i];const bool front=std::sin(i*r.curl+t*9+r.ph)>0;
                p.line(x0,y0,x1,y1,front?r.c:scale(r.c,0.6),fade);
                p.line(x0+1,y0,x1+1,y1,front?mix(r.c,WHITE,0.35):scale(r.c,0.45),fade);
            }
        }
        for (const Bit &b:bits) {
            if (b.y>1) continue;
            const double fw=b.mode==2?1:std::cos(b.flip),w=std::max(0.5,std::abs(fw)*b.w),ca=std::cos(b.ang),sa=std::sin(b.ang);
            const C32 c=fw>=0?b.c:scale(b.c,0.62);const double a=fade;
            if (b.mode==2) {p.dot(b.x,b.y,scale(b.c,0.8),a);p.dot(b.x+1,b.y,scale(b.c,0.6),a);continue;}
            p.shade(b.x-4,b.y-4,b.x+4,b.y+4,[&](double x,double y,Painter::Out &o)->C32 {
                const double dx=x-b.x,dy=y-b.y,u=dx*ca+dy*sa,v=-dx*sa+dy*ca;
                if (std::abs(u)>w/2+0.2 || std::abs(v)>b.h/2) return 0;
                o.a=a;
                return std::abs(fw)>0.92 && v<-b.h/2+1?WHITE:c;
            });
            if (std::abs(fw)>0.97) p.glow(b.x,b.y,5,mix(b.c,WHITE,0.5),0.35*fade);
        }
        ps.draw(p,FRONT);
        lights.draw(p);
    }
};

// core/fx.js の createFx：120Hz以上の細かさで進め、置き場所と左右反転を付けて描く。
struct Instance {
    std::unique_ptr<Effect> fx;
    double x,y,duration,t=0;
    bool flip;
    void update(double dt) {t+=dt;const int n=std::max(1,int(std::ceil(dt*120-1e-9)));for (int i=0;i<n;++i) fx->update(dt/n);}
    bool done() const {return t>=duration;}
};

void palette7(PackedColorArray in,C32 *out) {for (int i=0;i<7;++i) out[i]=from_color(in[int(std::round(double(i)*(in.size()-1)/6.0))]);}
}

struct SpeedPixelFx::Impl {
    Frame frame;
    Rng rng{3};
    Particles sparkles{&rng,{WHITE}};
    std::vector<Instance> effects;
};

SpeedPixelFx::SpeedPixelFx():impl_(std::make_unique<Impl>()) {}
SpeedPixelFx::~SpeedPixelFx()=default;

void SpeedPixelFx::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure","width","height","seed","sparks"),&SpeedPixelFx::configure);
    ClassDB::bind_method(D_METHOD("clear"),&SpeedPixelFx::clear);
    ClassDB::bind_method(D_METHOD("add_firework","at","seed","palette","core"),&SpeedPixelFx::add_firework);
    ClassDB::bind_method(D_METHOD("add_confetti","at","seed","flip","palette"),&SpeedPixelFx::add_confetti);
    ClassDB::bind_method(D_METHOD("spawn","kind","at","velocity","life","color","size"),&SpeedPixelFx::spawn);
    ClassDB::bind_method(D_METHOD("update","dt"),&SpeedPixelFx::update);
    ClassDB::bind_method(D_METHOD("is_empty"),&SpeedPixelFx::is_empty);
    ClassDB::bind_method(D_METHOD("render"),&SpeedPixelFx::render);
}

void SpeedPixelFx::configure(int width,int height,int seed,PackedColorArray sparks) {
    Impl &m=*impl_;
    m.frame.w=std::max(1,width);m.frame.h=std::max(1,height);
    m.frame.C.assign(size_t(m.frame.w)*m.frame.h,0);m.frame.L.assign(size_t(m.frame.w)*m.frame.h,0);
    m.rng=Rng(uint32_t(seed));
    std::vector<C32> s;for (int i=0;i<sparks.size();++i) s.push_back(from_color(sparks[i]));
    if (s.empty()) s.push_back(WHITE);
    m.sparkles=Particles(&m.rng,s);
    m.effects.clear();
}

void SpeedPixelFx::clear() {impl_->sparkles.list.clear();impl_->effects.clear();}

void SpeedPixelFx::add_firework(Vector2 at,int seed,PackedColorArray palette,PackedColorArray core) {
    if (palette.is_empty() || core.is_empty()) return;
    C32 c[7],k[7];palette7(palette,c);palette7(core,k);
    impl_->effects.push_back({std::make_unique<Firework>(c,k,uint32_t(seed)),at.x,at.y,3.6,0,false});
}

void SpeedPixelFx::add_confetti(Vector2 at,int seed,bool flip,PackedColorArray palette) {
    if (palette.is_empty()) return;
    C32 c[7];palette7(palette,c);
    impl_->effects.push_back({std::make_unique<Confetti>(c,uint32_t(seed)),at.x,at.y,3.4,0,flip});
}

void SpeedPixelFx::spawn(int kind,Vector2 at,Vector2 velocity,double life,Color color,double size) {
    impl_->sparkles.spawn(kind,at.x,at.y,velocity.x,velocity.y,life,from_color(color),size);
}

void SpeedPixelFx::update(double dt) {
    Impl &m=*impl_;
    for (Instance &e:m.effects) e.update(dt);
    m.effects.erase(std::remove_if(m.effects.begin(),m.effects.end(),[](const Instance &e) {return e.done();}),m.effects.end());
    m.sparkles.update(dt);
}

bool SpeedPixelFx::is_empty() const {return impl_->effects.empty() && impl_->sparkles.list.empty();}

// core/fx.js の composite(frame, out, null)：透明の上では光の最も明るい成分をalphaにする。
PackedByteArray SpeedPixelFx::render() {
    Impl &m=*impl_;Frame &f=m.frame;
    std::fill(f.C.begin(),f.C.end(),0);std::fill(f.L.begin(),f.L.end(),0);
    Painter p(&f);
    for (Instance &e:m.effects) {p.place(e.x,e.y,e.flip,0);p.fade=1;p.light_k=1;e.fx->draw_back(p);e.fx->draw(p);}
    p.place(0,0,false,0);p.fade=1;p.light_k=1;
    m.sparkles.draw(p,BOTH);
    PackedByteArray out;out.resize(int64_t(f.w)*f.h*4);
    uint8_t *o=out.ptrw();
    const int n=f.w*f.h;
    for (int i=0;i<n;++i) {
        const C32 c=f.C[i],l=f.L[i]&0xffffffu;
        double r,g,b,a;const int ca=int(c>>24);
        r=c&255;g=(c>>8)&255;b=(c>>16)&255;a=ca;
        if (l) {
            const double lr=l&255,lg=(l>>8)&255,lb=(l>>16)&255;
            if (a<255) {
                const double pa=a/255,pr=r*pa+lr,pg=g*pa+lg,pb=b*pa+lb;
                const double na=std::min(1.0,std::max(pa,std::max({lr,lg,lb})/255));
                if (na>0) {r=std::min(255.0,pr/na);g=std::min(255.0,pg/na);b=std::min(255.0,pb/na);a=na*255;}
            } else {r=std::min(255.0,r+lr);g=std::min(255.0,g+lg);b=std::min(255.0,b+lb);}
        }
        // Uint8ClampedArray と同じく四捨五入して詰める
        uint8_t *q=o+i*4;
        q[0]=uint8_t(std::lround(std::clamp(r,0.0,255.0)));q[1]=uint8_t(std::lround(std::clamp(g,0.0,255.0)));q[2]=uint8_t(std::lround(std::clamp(b,0.0,255.0)));q[3]=uint8_t(std::lround(std::clamp(a,0.0,255.0)));
    }
    return out;
}
}
