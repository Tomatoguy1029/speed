-- aseprite -b --script-param input=... --script-param output=... --script export_option_ui.lua
local source = app.open(app.params.input)
assert(source and source.width == 640 and source.height == 360, "Expected 640x360 option art")
for _, entry in ipairs({
  {"ui_layout_sound_selected", "layout"},
  {"ui_layout_screen_selected", "layout_display"},
  {"ui_layout_control", "layout_controls"},
  {"ui_gadgets", "gadgets"},
}) do
  local cel = assert(source.layers[entry[1]]:cel(1), "Missing layer " .. entry[1])
  local image = Image(640, 360, ColorMode.RGB)
  image:drawImage(cel.image, cel.position)
  local doubled = Image(1280, 720, ColorMode.RGB)
  for y = 0, 719 do
    for x = 0, 1279 do
      doubled:putPixel(x, y, image:getPixel(x // 2, y // 2))
    end
  end
  doubled:saveAs(app.params.output .. "/" .. entry[2] .. ".png")
end
source:close()
