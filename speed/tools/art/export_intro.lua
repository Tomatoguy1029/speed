-- aseprite --batch --script-param input=... --script-param output=... --script export_intro.lua
local source=assert(app.open(app.params.input),"Missing intro source")
assert(source.width==640 and source.height==360,"Expected 640x360 canvas")
local output=assert(app.params.output,"Missing output directory")
local wanted={scene1=true,["scene1-2alt"]=true,scene2=true,scene3=true,scene4=true,scene4_effects=true,scene5=true,scene5_stars1=true,scene5_stars2=true,scene5_stars3=true,scene6=true,scene7=true,outline=true}
local function visit(layers)
 for _,layer in ipairs(layers) do
  if layer.isGroup then visit(layer.layers)
  elseif wanted[layer.name] then
   local cel=assert(layer:cel(1),"Missing cel: "..layer.name)
   local image=Image(640,360,ColorMode.RGB)
   image:drawImage(cel.image,cel.position)
   image:saveAs(output.."/"..layer.name..".png")
   wanted[layer.name]=nil
  end
 end
end
visit(source.layers)
assert(next(wanted)==nil,"Missing intro layers")
source:close()
