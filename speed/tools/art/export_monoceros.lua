local sprite=Sprite{fromFile=app.params['source']}
assert(sprite and sprite.colorMode==ColorMode.RGB and #sprite.frames==1)
local destination=app.params['output']
local exported=0
local function export(layers)
 for _,layer in ipairs(layers) do
  if layer.isGroup then export(layer.layers)
  elseif layer.name~='Layer 1' and layer.name~='--------------' and layer.name~='flame' then
   local cel=layer:cel(1)
   if cel then
    local image=Image(sprite.width,sprite.height,ColorMode.RGB)
    image:drawImage(cel.image,cel.position)
    image:saveAs(destination..'/'..layer.name..'.png')
    exported=exported+1
   end
  end
 end
end
export(sprite.layers)
sprite:close()
print('Exported '..exported..' layer images')
