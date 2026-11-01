local f=assert(io.open(app.params['manifest'],'rb'))
local manifest=json.decode(f:read('*a'));f:close()
local sprite=Sprite{fromFile=manifest.source}
local before={}
for i,layer in ipairs(sprite.layers) do
 local cel=layer:cel(1)
 before[i]={name=layer.name,visible=layer.isVisible,bytes=cel and cel.image.bytes or nil}
end
local group=sprite:newGroup();group.name='Generated planar normals'
for _,item in ipairs(manifest.items) do
 local layer=sprite:newLayer();layer.parent=group;layer.name=item.name
 sprite:newCel(layer,1,Image{fromFile=item.path},Point(item.x,item.y))
end
group.isVisible=false
sprite:saveAs(manifest.destination)
for i,item in ipairs(before) do
 local layer=sprite.layers[i];assert(layer.name==item.name and layer.isVisible==item.visible)
 local cel=layer:cel(1);assert((cel and cel.image.bytes or nil)==item.bytes)
end
sprite:close()
