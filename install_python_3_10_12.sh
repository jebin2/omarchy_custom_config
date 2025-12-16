#!/bin/bash

set -e

echo ">>> Installing dependencies..."
sudo pacman -S --needed base-devel openssl zlib xz tk readline sqlite libffi bzip2 gcc make patch curl git

echo ">>> Installing pyenv..."
if [ ! -d "$HOME/.pyenv" ]; then
    curl https://pyenv.run | bash
else
    echo "pyenv already installed."
fi

CUSTOM_RC="$HOME/.omarchy_custom_bashrc"

echo ">>> Adding pyenv to $CUSTOM_RC ..."
if ! grep -q 'pyenv init' "$CUSTOM_RC"; then
cat << 'EOF' >> "$CUSTOM_RC"

# Pyenv setup (Omarchy Custom)
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF
fi

echo ">>> Reloading custom config..."
source "$CUSTOM_RC"

echo ">>> Installing Python 3.10.12..."
export CFLAGS="-I/usr/include"
export LDFLAGS="-L/usr/lib"

pyenv install 3.10.12

echo ">>> Setting Python 3.10.12 as global version..."
pyenv global 3.10.12

echo ">>> Done!"
python --version
