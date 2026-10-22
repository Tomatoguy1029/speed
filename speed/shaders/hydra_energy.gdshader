shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0,0.3,0.2,1.0);
uniform float clock = 0.0;
uniform float span = 300.0;
uniform float thickness = 32.0;
uniform int style = 0;
uniform bool warning = false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 grid=vec2(max(span/4.0,2.0),max(thickness/4.0,2.0));
 vec2 cell=floor(UV*grid);
 vec2 uv=(cell+0.5)/grid;
 float edge=abs(uv.y-0.5)*2.0;
 float grain=hash(cell+floor(clock*14.0));
 float flow=sin(uv.x*45.0-clock*10.0+uv.y*4.0)*0.5+0.5;
 float rim=step(edge,0.95-grain*0.1);
 float core=step(edge,0.22+flow*0.14);
 float sparks=step(0.90,grain)*step(edge,0.85);
 float alpha=rim*(0.45+core*0.55);
 vec3 col=tint.rgb*(0.7+flow*0.6)+core*vec3(1.2)+sparks*tint.rgb*1.5;
 if(style==1){
  // 風の帯：外へ流れる短い筋と圧縮された縁。
  float streak=pow(max(0.0,sin(uv.x*span/45.0-clock*13.0+sin(uv.y*16.0)*2.0)),10.0);
  col=tint.rgb*(0.7+streak*1.4)+vec3(streak*0.8);
  alpha=rim*(0.16+streak*0.7+sparks*0.4)+step(0.87,edge)*rim*0.3;
 }else if(style==2){
  // 雷：時間で刻む主幹、分枝、白い瞬間光。
  float jitter=(hash(vec2(floor(uv.x*grid.x/3.0),floor(clock*24.0)))-0.5)*0.45;
  float trunk=1.0-step(0.065,abs(uv.y-0.5-jitter));
  float branch=step(0.84,hash(vec2(floor(uv.x*12.0),floor(clock*18.0))))*(1.0-step(0.04,abs(fract(uv.x*5.0+uv.y*1.8)-0.5)));
  col=tint.rgb*(0.5+branch*2.0)+vec3(trunk*2.1);
  alpha=rim*(0.15+trunk*0.85+branch*0.65+sparks*0.3);
 }else if(style==3){
  // 瓦礫：暗い割れ目、段階のある石の面、飛ぶ火花。
  float plate=hash(floor(cell/3.0));
  float crack=step(0.82,fract(uv.x*9.0+uv.y*4.0));
  col=tint.rgb*(0.45+floor(plate*3.0)*0.35)*(1.0-crack*0.7)+sparks*vec3(1.2,0.7,0.3);
  alpha=rim;
 }else if(style==4){
  // 瓦礫竜巻：回転する風の筋の間に石の塊。
  float spin=sin(uv.x*28.0+uv.y*18.0-clock*18.0)*0.5+0.5;
  float rock=step(0.72,hash(floor(vec2(uv.x*20.0-clock*3.0,uv.y*8.0))));
  col=mix(tint.rgb*(0.6+spin*1.4),vec3(0.38,0.28,0.18),rock);
  alpha=rim*(0.25+spin*0.6+rock*0.2);
 }else if(style==5){
  // 飛ぶ光弾：明るい先端と短い筋。
  col+=vec3(1.0)*step(0.72,uv.x)*core;
  alpha*=0.35+0.65*uv.x;
 }
 if(warning){
  float marks=step(0.45,fract(uv.x*span/28.0-clock*1.5));
  col=mix(tint.rgb,vec3(1.0,0.85,0.45),0.7);
  alpha=rim*(0.18+0.4*marks)*step(0.65,edge)+0.08*rim;
 }
 COLOR=vec4(col,clamp(alpha,0.0,1.0));
}
