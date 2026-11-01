local source=Sprite{fromFile=app.params['source']}
local destination=app.params['output']
local normals=Sprite{fromFile=app.params['normals']}
for _,name in ipairs({'star','large_star'}) do
 local found=nil
 for _,layer in ipairs(source.layers) do if string.lower(layer.name)==name then found=layer end end
 local cel=assert(found):cel(1)
 cel.image:saveAs(destination..'/'..name..'.png')
 local target=nil
 for _,layer in ipairs(normals.layers) do if string.lower(layer.name)==name then target=layer end end
 if not target then target=normals:newLayer();target.name=name end
 if target:cel(1) then normals:deleteCel(target:cel(1)) end
 normals:newCel(target,1,cel.image,cel.position)
end
normals:saveAs(app.params['normals'])
normals:close();source:close()
