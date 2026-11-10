#!/bin/sh
# Monitor layout and screen blanking. Run once per login by config/autostart.lua,
# and from the awesome menu -> re-apply displays. The layout is the one in
# ~/.screenlayout/default2.sh (made with arandr)

status=0

xrandr \
    --output DP-0 --off \
    --output DP-1 --mode 1920x1080 --pos 5120x1680 --rotate left \
    --output HDMI-0 --primary --mode 2560x1440 --pos 2560x2160 --rotate normal \
    --output DP-2 --mode 3840x2160 --pos 1280x0 --rotate normal \
    --output DP-3 --off \
    --output DP-4 --mode 2560x1440 --pos 0x2160 --rotate normal \
    --output DP-5 --off \
    --output USB-C-0 --off || status=$?

# never blank or power off the monitors; modules/idle_dim.lua dims them instead
xset -dpms
xset s noblank
xset s off

exit $status
