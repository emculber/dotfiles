#!/bin/sh
# Screenshots every theme (or the ones named) in a throwaway Xephyr session,
# with a few windows, a notification and the main menu open, then puts them
# side by side in one contact sheet. Nothing changes in the real session.
#
# Usage: preview-themes.sh [THEME ...]
#   preview-themes.sh                      every theme
#   preview-themes.sh nord dracula         just these
# Output: ~/Pictures/awesome-themes/<theme>.png and contact-sheet.png

config="$HOME/.config/awesome"
out="${PREVIEW_DIR:-$HOME/Pictures/awesome-themes}"
display=:6
size=1280x720
# display-setup.sh would run xrandr with the real monitor names
AWESOME_NO_AUTOSTART=1
export AWESOME_NO_AUTOSTART
mkdir -p "$out"

# one theme, run inside its own D-Bus session so notify-send and
# awesome-client reach this awesome and not the real one
shoot() {
    awesome -c "$config/rc.lua" >/dev/null 2>&1 &
    awesome=$!
    for _ in $(seq 50); do
        xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q window && break
        sleep 0.1
    done

    for n in 1 2 3; do
        kitty -o font_size=10 -T "window $n" sh -c "printf '%s\n' '$AWESOME_THEME — window $n'; sleep 60" >/dev/null 2>&1 &
    done
    sleep 1.5
    # one window on tag 3 so the bar shows an occupied tag
    awesome-client 'local c = client.get()[1] if c then c:move_to_tag(screen[1].tags[3]) end' >/dev/null
    notify-send "Theme: $AWESOME_THEME" "This is what a notification looks like."
    awesome-client 'require("config.menu").main:show({ coords = { x = 30, y = 60 } })' >/dev/null
    sleep 1
    scrot -o "$1"

    kill $awesome
    pkill -P $$ kitty 2>/dev/null
}

if [ "$1" = --shoot ]; then
    shoot "$2"
    exit
fi

if [ $# -eq 0 ]; then
    set -- $(
        {
            ls "$config/themes" | sed -n 's/\.lua$//p' | grep -vx base
            ls "$config/themes/palettes" | sed -n 's/\.lua$//p'
        } | sort
    )
fi

for theme in "$@"; do
    Xephyr "$display" -br -ac -noreset -dpi "${XEPHYR_DPI:-161}" -screen "$size" >/dev/null 2>&1 &
    xephyr=$!
    for _ in $(seq 25); do
        [ -S "/tmp/.X11-unix/X${display#:}" ] && break
        sleep 0.2
    done

    echo "previewing $theme"
    DISPLAY=$display AWESOME_THEME=$theme dbus-run-session -- "$0" --shoot "$out/$theme.png" >/dev/null 2>&1

    kill $xephyr 2>/dev/null
    wait $xephyr 2>/dev/null
done

if command -v montage >/dev/null; then
    cd "$out" || exit 1
    shots=""
    for theme in "$@"; do
        [ -f "$theme.png" ] && shots="$shots $theme.png"
    done
    # shellcheck disable=SC2086
    montage -label '%t' -font DejaVu-Sans -pointsize 18 -background '#111111' -fill '#dddddd' \
        -geometry 640x360+8+8 -tile 4x $shots contact-sheet.png
    echo "contact sheet: $out/contact-sheet.png"
fi
