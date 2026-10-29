-- Composite authored layers per part; keep guide/reference layers in the source only.
local sprite=Sprite{fromFile=app.params['source']}
assert(sprite and sprite.colorMode==ColorMode.RGB and #sprite.frames==1)
local parts={
 {name='body',rect=Rectangle(17,63,58,86)},
 {name='head',rect=Rectangle(22,140,48,71)},
 {name='leg_back',rect=Rectangle(99,46,35,82)},
 {name='leg_front',rect=Rectangle(140,137,31,75)},
 {name='tail',rect=Rectangle(130,3,51,99)}
}
for _,part in ipairs(parts) do
 local full=Image(sprite.width,sprite.height,ColorMode.RGB)
 local count=0
 for _,layer in ipairs(sprite.layers) do
  if string.find(layer.name,part.name,1,true) and layer.name~='reference' then
   local cel=assert(layer:cel(1))
   full:drawImage(cel.image,cel.position)
   count=count+1
  end
 end
 assert(count>=2,'Missing part layers: '..part.name)
 local cropped=Image(full,part.rect)
 cropped:saveAs(app.params['output']..'/'..part.name..'.png')
end
sprite:close()
