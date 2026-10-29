-- Compose fixed body/compass layers before runtime; authored normal pixels stay unchanged.
local root=app.params['root']
local destination=app.params['output']
local diffuse=Image{fromFile=root..'/hydra.png'}
local compass=Image{fromFile=destination..'/hydra_compass.png'}
local bodyNormal=Image{fromFile=destination..'/hydra_body_normal.png'}
local compassNormal=Image{fromFile=destination..'/hydra_compass_normal.png'}
assert(diffuse.width==128 and diffuse.height==128)
assert(compass.width==128 and compass.height==128 and bodyNormal.width==128 and bodyNormal.height==128 and compassNormal.width==128 and compassNormal.height==128)
local normal=Image(128,128,ColorMode.RGB)
normal:clear(app.pixelColor.rgba(128,128,255,255))
normal:drawImage(bodyNormal)
normal:drawImage(compassNormal)
diffuse:drawImage(compass)
diffuse:saveAs(destination..'/hydra_body.png')
normal:saveAs(destination..'/hydra_body_lit_normal.png')
