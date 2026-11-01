-- Export named layers at original canvas coordinates, excluding references and hidden variants.
local s=Sprite{fromFile=app.params['source']}
local output=app.params['output']
local images={base=Image(s.width,s.height,ColorMode.RGB),armor=Image(s.width,s.height,ColorMode.RGB),normal=Image(s.width,s.height,ColorMode.RGB)}
for _,l in ipairs(s.layers) do
 if images[l.name] then local c=assert(l:cel(1));images[l.name]:drawImage(c.image,c.position) end
 if l.name=='Generated planar normals' then
  for _,n in ipairs(l.layers) do
   local c=assert(n:cel(1));images.normal=Image(s.width,s.height,ColorMode.RGB);images.normal:drawImage(c.image,c.position)
  end
 end
end
-- Keep authored normal RGB intact; trim only pixels outside the armor mask.
for y=0,s.height-1 do for x=0,s.width-1 do
 local a=app.pixelColor.rgbaA(images.armor:getPixel(x,y))
 local n=images.normal:getPixel(x,y)
 assert(a==0 or app.pixelColor.rgbaA(n)>0,'Normal missing under armor')
 images.normal:putPixel(x,y,a==0 and 0 or app.pixelColor.rgba(app.pixelColor.rgbaR(n),app.pixelColor.rgbaG(n),app.pixelColor.rgbaB(n),a))
end end
for name,image in pairs(images) do image:saveAs(output..'/'..name..'.png') end
s:close()
