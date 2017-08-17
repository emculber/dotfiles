local awful = require("awful")
local beautiful = require("beautiful")

local env = {}

function env:init(args)
  print("Init configure environment variables")
  local args = args or {}

  self.modkey = args.modkey or "Mod4"

  beautiful.init(awful.util.get_themes_dir() .. "default/theme.lua")
end

return env
