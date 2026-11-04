-- aseprite --batch --script-param input=... --script-param output=... --script export_selection_screen.lua
-- Export hidden stage pairs without flattening their authored canvas positions.
local source=app.open(app.params['input'])
local output=app.params['output']
assert(source and output and source.width==640 and source.height==360,'Expected the 640x360 selection screen')
local function find(name, detail)
 local found=nil
 local function visit(layers)
  for _,layer in ipairs(layers) do
   if layer.isGroup then visit(layer.layers)
   elseif layer.name==name then
    local cel=layer:cel(1)
    if cel and (not detail or cel.position.x>=440) then
     assert(not found,'Ambiguous layer: '..name)
     found=cel
    end
   end
  end
 end
 visit(source.layers)
 assert(found,'Missing layer: '..name)
 return found
end
local function export(cel,file,region)
 region=region or Rectangle(0,0,640,360)
 local image=Image(region.width,region.height,ColorMode.RGB)
 image:drawImage(cel.image,Point(cel.position.x-region.x,cel.position.y-region.y))
 image:saveAs(output..'/'..file..'.png')
end
export(find('UI stuff',false),'selection_screen_ui_arts')
export(find('decorations',false),'selection_highlight',Rectangle(141,207,112,59))
for _,entry in ipairs({{'unicorn','unicorn','unicorn'},{'centaurus','centeur','centeur_ui'},{'dog','dog','dog'},{'snake','snake','snake'}}) do
 export(find(entry[2]..'_stars',true),'preview_'..entry[1]..'_stars')
 export(find(entry[3],true),'preview_'..entry[1])
end
for phase=1,5 do
 local name='stars_phase'..phase
 export(find(name,false),name)
end
source:close()
print('Exported selection icons, yellow highlight, four authored preview pairs and five star layers.')
