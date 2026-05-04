#!/bin/bash
set -eo pipefail

DEFAULT_PYTHON_VERSION="3.10.12"
read -p "Enter Python version to install [$DEFAULT_PYTHON_VERSION]: " input_version
PYTHON_VERSION="${input_version:-$DEFAULT_PYTHON_VERSION}"
PYENV_DIR="$HOME/.pyenv"

# Detect shell
IS_FISH=false
IS_ZSH=false
if echo "$SHELL" | grep -q "fish"; then
    IS_FISH=true
elif echo "$SHELL" | grep -q "zsh"; then
    IS_ZSH=true
fi

# Set shell-specific paths
FISH_CONFIG="$HOME/.config/fish/config.fish"
FISH_FUNCTIONS_DIR="$HOME/.config/fish/functions"

if [ "$IS_ZSH" = true ]; then
    SHELL_RC="$HOME/.zshrc"
    CUSTOM_RC="$HOME/.custom_zshrc"
    LOCAL_CUSTOM_RC="./custom_zshrc"
    CUSTOM_RC_FILENAME="custom_zshrc"
elif [ "$(uname -s)" = "Darwin" ] && echo "$SHELL" | grep -q "bash"; then
    SHELL_RC="$HOME/.bash_profile"
    CUSTOM_RC="$HOME/.custom_bashrc"
    LOCAL_CUSTOM_RC="./custom_bashrc"
    CUSTOM_RC_FILENAME="custom_bashrc"
else
    SHELL_RC="$HOME/.bashrc"
    CUSTOM_RC="$HOME/.custom_bashrc"
    LOCAL_CUSTOM_RC="./custom_bashrc"
    CUSTOM_RC_FILENAME="custom_bashrc"
fi

echo ">>> Detecting OS..."

if [ "$(uname -s)" = "Darwin" ]; then
    OS="macos"
    if ! command -v brew >/dev/null 2>&1; then
        echo "❌ Homebrew is required on macOS. Please install it first."
        exit 1
    fi
elif command -v pacman >/dev/null 2>&1; then
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

elif [ "$OS" = "macos" ]; then
    brew update
    brew install openssl readline sqlite3 xz zlib tcl-tk
fi

# ----------------------------
# Copy custom rc (bash/zsh)
# ----------------------------
if [ "$IS_FISH" = false ]; then
    if [ -f "$LOCAL_CUSTOM_RC" ]; then
        echo ">>> Copying $CUSTOM_RC_FILENAME to home..."
        cp "$LOCAL_CUSTOM_RC" "$CUSTOM_RC"
    else
        echo ">>> Downloading $CUSTOM_RC_FILENAME from GitHub..."
        curl -fsSL "https://raw.githubusercontent.com/jebin2/omarchy_custom_config/main/$CUSTOM_RC_FILENAME?t=$(date +%s)" -o "$CUSTOM_RC"
    fi
fi

# ----------------------------
# Ensure shell profile sources custom rc
# ----------------------------
if [ "$IS_FISH" = false ]; then
    echo ">>> Ensuring $CUSTOM_RC is sourced in $SHELL_RC..."

    if ! grep -q "$CUSTOM_RC_FILENAME" "$SHELL_RC" 2>/dev/null; then
        cat >> "$SHELL_RC" << EOF

# Load custom config
[ -f "\$HOME/$CUSTOM_RC_FILENAME" ] && source "\$HOME/$CUSTOM_RC_FILENAME"
EOF
    else
        echo "✔ $CUSTOM_RC already sourced in $SHELL_RC"
    fi
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
            echo ">>> Downloading $f from GitHub..."
            curl -fsSL "https://raw.githubusercontent.com/jebin2/omarchy_custom_config/main/$f?t=$(date +%s)" -o "$FISH_FUNCTIONS_DIR/$f"
            echo "✔ Installed $f -> $FISH_FUNCTIONS_DIR/$f"
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
    curl -fsSL https://pyenv.run | bash
else
    echo "✔ pyenv already installed"
fi

# ----------------------------
# Load environment
# ----------------------------
echo ">>> Reloading environment..."
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if [ "$IS_FISH" = false ] && [ "$IS_ZSH" = false ]; then
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
pyenv exec python --version
