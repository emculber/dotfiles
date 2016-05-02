DOTFILES=$HOME/.dotfiles

echo "\nRunning Sub-Installers"
echo "=============================="

installers=$(find -H $DOTFILES -maxdepth 3 -name '*_install.sh')
for installer in $installers ; do
  sh $installer
done
