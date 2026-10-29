// 試作のpringUと同じ、円周を丸めたドット。近い角度だけ調べ、同じドットを重ねない。
float pixel_ring(vec2 cell, float radius) {
 if(radius <= 0.0 || abs(length(cell)-radius) > 0.72) return 0.0;
 float count = ceil(radius*8.0);
 float nearest = floor(atan(cell.y,cell.x)*count/6.28318530718+0.5);
 for(int k=-2;k<=2;k++) {
  float a = (nearest+float(k))*6.28318530718/count;
  vec2 sample_cell = floor(vec2(cos(a),sin(a))*radius+0.5);
  if(all(equal(sample_cell,cell))) return 1.0;
 }
 return 0.0;
}
