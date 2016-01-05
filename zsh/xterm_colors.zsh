# Base16 Shell
if [ -z "$THEME" ]; then
  export THEME="base16-Isotope"
fi
if [ -z "$BACKGROUND" ]; then
  export BACKGROUND="dark"
fi

BASE16_SHELL="$DOTFILES/themes/base16-shell/$THEME.$BACKGROUND.sh"
# [[ -s $BASE16_SHELL ]] && source $BASE16_SHELL
source $BASE16_SHELL
