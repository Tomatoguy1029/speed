-- Export authored pixels without changing either source document.
local output=app.params['output']
for _,kind in ipairs({'hydra_neck','hydra_undead_neck'}) do
 local sprite=Sprite{fromFile=app.params[kind]}
 assert(sprite and sprite.colorMode==ColorMode.RGB and #sprite.frames==1)
 local diffuse=Image(sprite.width,sprite.height,ColorMode.RGB)
 local normal=Image(sprite.width,sprite.height,ColorMode.RGB)
 for _,layer in ipairs(sprite.layers) do
  local cel=layer:cel(1)
  if cel and layer.name~='Layer 1' then
   local target=layer.name=='normal' and normal or diffuse
   target:drawImage(cel.image,cel.position)
  end
 end
 diffuse:saveAs(output..'/'..kind..'.png')
 normal:saveAs(output..'/'..kind..'_normal.png')
 sprite:close()
end
