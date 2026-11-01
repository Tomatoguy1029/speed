-- Export the authored head layers; head 2 names its final normal layer "armor".
local output=app.params['output']
for _,name in ipairs({'hydra_head','hydra_head_2','hydra_head_3'}) do
 local sprite=Sprite{fromFile=app.params[name]}
 assert(sprite and sprite.colorMode==ColorMode.RGB and #sprite.frames==1)
 local diffuse=Image(sprite.width,sprite.height,ColorMode.RGB)
 local normal=Image(sprite.width,sprite.height,ColorMode.RGB)
 normal:clear(app.pixelColor.rgba(128,128,255,255))
 for i,layer in ipairs(sprite.layers) do
  local cel=layer:cel(1)
  if cel and layer.name~='Layer 1' then
   local isNormal=layer.name=='normal' or (name=='hydra_head_2' and i==#sprite.layers)
   if isNormal then normal:drawImage(cel.image,cel.position)
   else diffuse:drawImage(cel.image,cel.position) end
  end
 end
 diffuse:saveAs(output..'/'..name..'.png')
 normal:saveAs(output..'/'..name..'_normal.png')
 sprite:close()
end
