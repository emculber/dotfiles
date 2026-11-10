# dotfiles

My Linux desktop: AwesomeWM, zsh (oh-my-zsh), neovim (LazyVim), kitty, tmux.

## Layout
| Path | Linked to | What |
|------|-----------|------|
| `awesome/` | `~/.config/awesome` | AwesomeWM config (see `awesome/config/settings.lua`); the Claude usage widget is a submodule |
| `nvim/` | `~/.config/nvim` | LazyVim config; `lazy-lock.json` pins the plugins |
| `kitty/` | `~/.config/kitty` | kitty config, Nerd Font symbol mapping, Argonaut colours |
| `zsh/zshrc.symlink` | `~/.zshrc` | oh-my-zsh config |
| `bash/bashrc.symlink` | `~/.bashrc` | |
| `git/gitconfig.symlink` | `~/.gitconfig` | |
| `tmux/tmux.conf.symlink` | `~/.tmux.conf` | |
| `idea/ideavimrc.symlink` | `~/.ideavimrc` | IdeaVim (JetBrains) |

Any `<dir>/<name>.symlink` becomes `~/.<name>`.

## Install on a new machine
```sh
git clone git@github.com:emculber/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```
`install.sh` fetches the submodule, runs `install/link.sh` (which never overwrites
an existing file: move it away first) and makes zsh the login shell.

## Not tracked here
- **oh-my-zsh** and its custom plugins (zsh-autosuggestions, zsh-syntax-highlighting,
  fast-syntax-highlighting, zsh-autocomplete). `install.sh` prints the commands if it's missing.
- **Fonts:** Symbols Nerd Font in `~/.local/share/fonts` (kitty's `font-nerd-symbols.conf`).
  kitty.conf asks for Iosevka Nerd Font Mono, which isn't installed at the moment.
- **Packages:** awesome, kitty, neovim, tmux, zsh, and for the awesome widgets: wpctl/pw-dump/jq
  (PipeWire), playerctl, pavucontrol, borg, ClamAV, protonvpn.
