-- Offline export of the authored horn animation and its matching normal layer.
local s=Sprite{fromFile=app.params['source']}
local out=app.params['output']
local normal=assert(s.layers['Generated planar normals'].layers['horn_normal'])
local count=#s.frames
local colorAtlas=Image(s.width*count,s.height,ColorMode.RGB)
local normalAtlas=Image(s.width*count,s.height,ColorMode.RGB)
local lengths,durations={},{}
for i,frame in ipairs(s.frames) do
 local color=Image(s.width,s.height,ColorMode.RGB)
 color:drawSprite(s,i)
 local n=Image(s.width,s.height,ColorMode.RGB)
 local cel=assert(normal:cel(i));n:drawImage(cel.image,cel.position)
 for y=0,s.height-1 do for x=0,s.width-1 do
  assert(app.pixelColor.rgbaA(color:getPixel(x,y))==app.pixelColor.rgbaA(n:getPixel(x,y)))
 end end
 -- The authored horn root is (23.5,4); ignore detached light particles below the tip.
 local tip=10
 assert(app.pixelColor.rgbaA(color:getPixel(23,tip))>0)
 while tip+1<s.height and app.pixelColor.rgbaA(color:getPixel(23,tip+1))>0 do tip=tip+1 end
 table.insert(lengths,tostring(tip-4+1));table.insert(durations,tostring(frame.duration))
 colorAtlas:drawImage(color,Point((i-1)*s.width,0))
 normalAtlas:drawImage(n,Point((i-1)*s.width,0))
end
colorAtlas:saveAs(out..'/horn.png');normalAtlas:saveAs(out..'/horn_normal.png')
local f=assert(io.open(out..'/horn.tres','w'))
f:write('[gd_resource type="CanvasTexture" load_steps=3 format=3]\n')
f:write('[ext_resource type="Texture2D" path="res://assets/pixel/monoceros/horn/horn.png" id="1"]\n')
f:write('[ext_resource type="Texture2D" path="res://assets/pixel/monoceros/horn/horn_normal.png" id="2"]\n')
f:write('[resource]\ndiffuse_texture = ExtResource("1")\nnormal_texture = ExtResource("2")\ntexture_filter = 1\n')
f:write('metadata/core_lengths = PackedFloat32Array('..table.concat(lengths,', ')..')\n')
f:write('metadata/durations = PackedFloat32Array('..table.concat(durations,', ')..')\n');f:close()
s:close()
print('Exported '..count..' matching color/normal frames; core lengths '..table.concat(lengths,','))
