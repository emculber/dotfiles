local awful = require("awful")
local beautiful = require("beautiful")

local menu = {}

function menu:init(args)

  local awesomemenu = {
    { "hotkeys", function() return false, hotkeys_popup.show_help end},
    --{ "manual", terminal .. " -e man awesome" },
    --{ "edit config", editor_cmd .. " " .. awesome.conffile },
    { "restart", awesome.restart },
    { "quit", function() awesome.quit() end}
  }


  local mainmenu = awful.menu({ 
    items = 
    { 
      { "awesome", awesomemenu, beautiful.awesome_icon },
      { "Debian", debian.menu.Debian_menu.Debian },
      { "open terminal", terminal }
    }
  })

  self.launcher = awful.widget.launcher({ 
    image = beautiful.awesome_icon,
    menu = mainmenu 
  })

  --menubar.utils.terminal = terminal -- Set the terminal for applications that require it
  
end

return menu
