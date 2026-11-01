-- Export only authored paint layers; guide boxes and references stay in the source file.
local sprite=Sprite{fromFile=app.params['source']}
assert(sprite and sprite.colorMode==ColorMode.RGB and #sprite.frames==1)
local names={base=true,armor=true,bow=true,armor_normal=true,bow_normal=true}
local expected=nil
if app.params['layers'] then
 local allowed=names
 names={};expected=0
 for name in string.gmatch(app.params['layers'],'[^,]+') do
  assert(allowed[name],'Unknown paint layer: '..name)
  if not names[name] then names[name]=true;expected=expected+1 end
 end
 assert(expected>0)
end
local count=0
local function export(layers)
 for _,layer in ipairs(layers) do
 if layer.isGroup then export(layer.layers)
 elseif names[layer.name] then
  local cel=assert(layer:cel(1))
  local image=Image(sprite.width,sprite.height,ColorMode.RGB)
  image:drawImage(cel.image,cel.position)
  image:saveAs(app.params['output']..'/'..layer.name..'.png')
  count=count+1
 end
end
end
export(sprite.layers)
assert(expected and count==expected or not expected and (count==3 or count==5))
sprite:close()
print('Exported '..count..' paint/normal layers; source file unchanged')
