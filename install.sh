#!/bin/bash

echo "Installing dotfiles"

echo "Initializing submodule(s)"
git submodule update --init --recursive

echo "Initializing system links"
source ~/.dotfiles/install/link.sh
