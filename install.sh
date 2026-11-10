#!/bin/sh
# Sets up these dotfiles on a new machine. Safe to run again.
cd "$(dirname "$0")" || exit 1

echo "Installing dotfiles"

echo "Initializing submodule(s)"
git submodule update --init --recursive

sh install/link.sh

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    cat <<'MSG'

oh-my-zsh isn't installed. zshrc expects it and these custom plugins:
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc
  cd ~/.oh-my-zsh/custom/plugins
  git clone https://github.com/zsh-users/zsh-autosuggestions.git
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git
  git clone https://github.com/marlonrichert/zsh-autocomplete.git
MSG
fi

if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
    echo "Configuring zsh as default shell"
    chsh -s "$(command -v zsh)"
fi

echo "Done!"
