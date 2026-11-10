#!/bin/sh
# Links the dotfiles into $HOME. Anything already there is left alone.
#   <dir>/<name>.symlink  ->  ~/.<name>     (zshrc, bashrc, gitconfig, tmux.conf, ideavimrc)
#   awesome, nvim, kitty  ->  ~/.config/<name>

DOTFILES=$(cd "$(dirname "$0")/.." && pwd)

link() {
    if [ -e "$2" ] || [ -L "$2" ]; then
        echo "~${2#"$HOME"} already exists... Skipping."
    else
        echo "Linking ~${2#"$HOME"} -> $1"
        ln -s "$1" "$2"
    fi
}

echo "Creating symlinks"
echo "=============================="
find "$DOTFILES" -mindepth 2 -maxdepth 2 -name '*.symlink' -not -path '*/.git/*' | sort | while read -r file; do
    link "$file" "$HOME/.$(basename "$file" .symlink)"
done

mkdir -p "$HOME/.config"
for dir in awesome nvim kitty; do
    link "$DOTFILES/$dir" "$HOME/.config/$dir"
done
