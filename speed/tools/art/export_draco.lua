-- Export fixed source rectangles offline, keeping guide/reference layers out of the game.
local s=Sprite{fromFile=app.params['source']}
local diffuse=Image(s.width,s.height,ColorMode.RGB)
local normal=Image(s.width,s.height,ColorMode.RGB)
normal:clear(app.pixelColor.rgba(128,128,255,255))
for _,l in ipairs(s.layers) do
 if l.name=='base' or l.name=='armor' then
  local c=assert(l:cel(1));diffuse:drawImage(c.image,c.position)
 elseif l.name=='Generated planar normals' then
  for _,n in ipairs(l.layers) do local c=assert(n:cel(1));normal:drawImage(c.image,c.position) end
 end
end
local parts={
 {'head',50,270,75,100},
 {'arm',145,214,33,37}, {'claw',176,265,28,28},
 {'body_a',208,198,62,52}, {'body_b',285,198,65,52}, {'body_c',359,198,66,52},
 {'body_d',207,312,65,53}, {'body_e',289,294,57,72},
 {'tail_tip',420,270,40,55}, {'tail_joint',371,307,48,56}
}
for _,p in ipairs(parts) do
 local rect=Rectangle(p[2],p[3],p[4],p[5])
 local color=Image(diffuse,rect); local normals=Image(normal,rect)
 for y=0,color.height-1 do for x=0,color.width-1 do
  local a=app.pixelColor.rgbaA(color:getPixel(x,y));local n=normals:getPixel(x,y)
  normals:putPixel(x,y,app.pixelColor.rgba(app.pixelColor.rgbaR(n),app.pixelColor.rgbaG(n),app.pixelColor.rgbaB(n),a))
 end end
 color:saveAs(app.params['output']..'/'..p[1]..'.png');normals:saveAs(app.params['output']..'/'..p[1]..'_normal.png')
end
s:close()
