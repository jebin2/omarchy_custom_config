#!/bin/bash
set -e

PYTHON_VERSION="3.10.12"
PYENV_DIR="$HOME/.pyenv"

CUSTOM_RC="$HOME/.custom_bashrc"
LOCAL_CUSTOM_RC="./custom_bashrc"
BASHRC="$HOME/.bashrc"

echo ">>> Detecting OS..."

if command -v pacman >/dev/null 2>&1; then
    OS="arch"
elif command -v apt >/dev/null 2>&1; then
    OS="ubuntu"
else
    echo "❌ Unsupported OS"
    exit 1
fi

echo ">>> OS detected: $OS"

# ----------------------------
# Install dependencies
# ----------------------------
echo ">>> Installing dependencies..."

if [ "$OS" = "arch" ]; then
    sudo pacman -S --needed --noconfirm \
        base-devel openssl zlib xz tk readline sqlite libffi \
        bzip2 gcc make patch curl git

elif [ "$OS" = "ubuntu" ]; then
    sudo apt update
    sudo apt install -y \
        build-essential curl git \
        libssl-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev \
        libffi-dev liblzma-dev tk-dev \
        xz-utils
fi

# ----------------------------
# Copy .custom_bashrc
# ----------------------------
if [ -f "$LOCAL_CUSTOM_RC" ]; then
    echo ">>> Copying custom_bashrc to home..."
    cp "$LOCAL_CUSTOM_RC" "$CUSTOM_RC"
else
    echo "⚠️  No .custom_bashrc found in current directory"
fi

# ----------------------------
# Ensure .bashrc sources .custom_bashrc
# ----------------------------
echo ">>> Ensuring ~/.custom_bashrc is sourced in ~/.bashrc..."

if ! grep -q 'source ~/.custom_bashrc' "$BASHRC" 2>/dev/null; then
    cat << 'EOF' >> "$BASHRC"

# Load custom bash config
[ -f ~/.custom_bashrc ] && source ~/.custom_bashrc
EOF
else
    echo "✔ ~/.custom_bashrc already sourced"
fi

# ----------------------------
# Install pyenv
# ----------------------------
echo ">>> Installing pyenv..."

if [ ! -d "$PYENV_DIR" ]; then
    curl https://pyenv.run | bash
else
    echo "✔ pyenv already installed"
fi

# ----------------------------
# Configure pyenv in .custom_bashrc
# ----------------------------
echo ">>> Configuring pyenv in ~/.custom_bashrc..."

if ! grep -q 'pyenv init' "$CUSTOM_RC" 2>/dev/null; then
cat << 'EOF' >> "$CUSTOM_RC"

# >>> pyenv setup >>>
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv >/dev/null; then
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
fi
# <<< pyenv setup <<<
EOF
fi

# ----------------------------
# Load environment
# ----------------------------
echo ">>> Reloading ~/.custom_bashrc..."
source "$CUSTOM_RC"

# ----------------------------
# Install Python
# ----------------------------
if pyenv versions --bare | grep -q "^$PYTHON_VERSION$"; then
    echo "✔ Python $PYTHON_VERSION already installed"
else
    echo ">>> Installing Python $PYTHON_VERSION..."
    pyenv install "$PYTHON_VERSION"
fi

# ----------------------------
# Set global Python
# ----------------------------
echo ">>> Setting global Python version..."
pyenv global "$PYTHON_VERSION"

echo ">>> Done!"
python --version
