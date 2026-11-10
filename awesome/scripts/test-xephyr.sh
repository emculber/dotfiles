#!/bin/sh
# Runs this awesome config in a nested X server (Xephyr) so changes can be tried
# without restarting the real session. Closing the window ends the test.
#
# Usage: test-xephyr.sh [WIDTHxHEIGHT ...]
#   test-xephyr.sh                      one 1600x900 screen
#   test-xephyr.sh 1280x720 720x1280    two monitors side by side (multi-monitor test)

display=:5
log="${XDG_CACHE_HOME:-$HOME/.cache}/awesome/xephyr.log"
bus="${XDG_CACHE_HOME:-$HOME/.cache}/awesome/xephyr.dbus"
mkdir -p "$(dirname "$log")"

[ $# -eq 0 ] && set -- 1600x900

# display-setup.sh would run xrandr with the real monitor names
AWESOME_NO_AUTOSTART=1
export AWESOME_NO_AUTOSTART

width=0
height=0
for size in "$@"; do
    w=${size%x*}
    h=${size#*x}
    width=$((width + w))
    [ "$h" -gt "$height" ] && height=$h
done

# -dpi: render text at the same size as the real monitors (awesome computes 161 there)
Xephyr "$display" -br -ac -noreset -dpi "${XEPHYR_DPI:-161}" -screen "${width}x${height}" &
xephyr=$!
trap 'kill $xephyr 2>/dev/null; rm -f "$bus"' EXIT INT TERM

# wait for the X socket
for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -S "/tmp/.X11-unix/X${display#:}" ] && break
    sleep 0.2
done

# Several sizes: rc.lua splits the screen into fake monitors (modules/fake_screens.lua).
# Xephyr can't fake real RandR monitors: awesome ignores ones without an output
if [ $# -gt 1 ]; then
    AWESOME_FAKE_SCREENS="$*"
    export AWESOME_FAKE_SCREENS
fi

echo "awesome log: $log"
echo "awesome-client for the test session:"
echo "  DBUS_SESSION_BUS_ADDRESS=\$(cat $bus) awesome-client"

# The nested awesome gets its own D-Bus session so awesome-client can reach it
# (on the shared bus the real awesome owns the name). Closing the Xephyr window
# makes awesome exit 1 ("X server connection broke"), the normal end of a test
DISPLAY=$display dbus-run-session -- sh -c \
    'echo "$DBUS_SESSION_BUS_ADDRESS" >"$1"; exec awesome -c "$2"' \
    sh "$bus" "$HOME/.config/awesome/rc.lua" >"$log" 2>&1 || true
