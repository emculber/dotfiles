local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
  print("--------------------Begin test------------------------------------------------------------")
local setmetatable = setmetatable
local test = { mt = {} }


function test.new(args, geometry, style)
  print("--------------------test -> Beginning test.new------------------------------------------------------------")
  print("Initializing Variables")
	local dwidget = {}

  print("Creating wibox")
  print("awful.screen", awful.screen)
  
  local midx = 100
  local midy = 100
  local wwidth = 100
  local wheight = 100
  awful.screen.connect_for_each_screen(function(s)
    --for k,v in pairs(s) do print("-- " .. k,v) end
    print(s.workarea.x)
    print(s.workarea.y)
    print(s.workarea.width)
    print(s.workarea.height)
    midx = ((s.workarea.width - s.workarea.x)/2) - wwidth/2
    midy = ((s.workarea.height - s.workarea.y-(wheight/2))/2)
    print(midx, midy)
  end)

    print(midx, midy)
	dwidget.wibox = wibox({ 
    type = "desktop", 
    visible = true, 
    bg = gears.color.transparent, 
    x=midx, 
    y=midy, 
    width=wwidth, 
    height=wheight, 
    border_color="#FFFFFF", 
    border_width=1,
  })

  print("wibox setup")
  dwidget.wibox : setup {
    fit    = function(self, context, width, height)
      print("fit")
      print(height)
      return height, height -- A square taking the full height
    end,
    draw   = function(self, context, cr, width, height)
      --print("draw")
      --print("height", height)
      cr:set_source_rgb(1, 0, 0) -- Red
      --cr:arc(height/2, height/2, height/2, 0, math.pi)
      local pi = math.pi
      local a = 100
      local b = 700
      local c = 100
      local d = 500
      local radius = 150
      cr:arc(a + radius, c + radius, radius, 2*(pi/2), 3*(pi/2))
      cr:arc(b - radius, c + radius, radius, 3*(pi/2), 4*(pi/2))
      cr:arc(b - radius, d - radius, radius, 0*(pi/2), 1*(pi/2))
      cr:arc(a + radius, d - radius, radius, 1*(pi/2), 2*(pi/2))
      cr:close_path()
      cr:stroke()
      cr:fill()
    end,
    layout = wibox.widget.base.make_widget,
  }
  local t = gears.timer({ timeout = .01 })

  local function update()
    if(dwidget.wibox.height == 400) then
      t:disconnect_signal("timeout", update)    
    end
    --print("update")
    dwidget.wibox.height = dwidget.wibox.height + 2
    dwidget.wibox.y = dwidget.wibox.y - 1
    dwidget.wibox.width = dwidget.wibox.width + 2
    dwidget.wibox.x = dwidget.wibox.x - 1
  end

  t:connect_signal("timeout", update)
  t:start()
  t:emit_signal("timeout")

  print("--------------------test -> End test.new------------------------------------------------------------")
  return dwidget
end

function test.mt:__call(...)
  print("--------------------test -> Beginning test.mt:__call(...)------------------------------------------------------------")
  print("Returing test.new(...)")
  print("--------------------test -> End test.mt:__call(...)------------------------------------------------------------")

	return test.new(...)
end

  print("--------------------End test------------------------------------------------------------")
return setmetatable(test, test.mt)
