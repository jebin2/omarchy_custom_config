#!/bin/bash
set -e

PYTHON_VERSION="3.10.12"
PYENV_DIR="$HOME/.pyenv"

CUSTOM_RC="$HOME/.custom_bashrc"
LOCAL_CUSTOM_RC="./custom_bashrc"
BASHRC="$HOME/.bashrc"

# Detect if fish is the default shell
FISH_CONFIG="$HOME/.config/fish/config.fish"
FISH_FUNCTIONS_DIR="$HOME/.config/fish/functions"
IS_FISH=false
if echo "$SHELL" | grep -q "fish"; then
    IS_FISH=true
fi

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
    base-devel openssl xz tk readline sqlite libffi \
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
# Copy .custom_bashrc (bash)
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
# Fish shell setup
# ----------------------------
if [ "$IS_FISH" = true ]; then
    echo ">>> Fish shell detected — installing fish functions..."
    mkdir -p "$FISH_FUNCTIONS_DIR"

    for f in penv.fish penvd.fish docker-nuke.fish; do
        if [ -f "./$f" ]; then
            cp "./$f" "$FISH_FUNCTIONS_DIR/$f"
            echo "✔ Installed $f -> $FISH_FUNCTIONS_DIR/$f"
        else
            echo "⚠️  ./$f not found, skipping"
        fi
    done

    echo ">>> Configuring pyenv in fish config..."
    mkdir -p "$(dirname "$FISH_CONFIG")"
    touch "$FISH_CONFIG"
    if ! grep -q 'pyenv init' "$FISH_CONFIG" 2>/dev/null; then
        cat << 'EOF' >> "$FISH_CONFIG"

# >>> pyenv setup >>>
set -x PYENV_ROOT $HOME/.pyenv
set -x PATH $PYENV_ROOT/bin $PATH
if command -v pyenv > /dev/null
    pyenv init - fish | source
    pyenv virtualenv-init - fish | source
end
# <<< pyenv setup <<<
EOF
        echo "✔ pyenv added to fish config"
    else
        echo "✔ pyenv already in fish config"
    fi
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
# Configure pyenv in .custom_bashrc (bash only)
# ----------------------------
if [ "$IS_FISH" = false ]; then
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
fi

# ----------------------------
# Load environment
# ----------------------------
echo ">>> Reloading environment..."
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if [ "$IS_FISH" = false ]; then
    source "$CUSTOM_RC"
fi

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
