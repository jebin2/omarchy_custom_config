#!/bin/bash
set -e

DEFAULT_PYTHON_VERSION="3.10.12"
read -p "Enter Python version to install [$DEFAULT_PYTHON_VERSION]: " input_version
PYTHON_VERSION="${input_version:-$DEFAULT_PYTHON_VERSION}"
PYENV_DIR="$HOME/.pyenv"

CUSTOM_RC="$HOME/.custom_bashrc"
LOCAL_CUSTOM_RC="./custom_bashrc"
# Detect shell configuration file
if echo "$SHELL" | grep -q "zsh"; then
    SHELL_RC="$HOME/.zshrc"
elif [ "$(uname -s)" = "Darwin" ] && echo "$SHELL" | grep -q "bash"; then
    SHELL_RC="$HOME/.bash_profile"
else
    SHELL_RC="$HOME/.bashrc"
fi

# Detect if fish is the default shell
FISH_CONFIG="$HOME/.config/fish/config.fish"
FISH_FUNCTIONS_DIR="$HOME/.config/fish/functions"
IS_FISH=false
if echo "$SHELL" | grep -q "fish"; then
    IS_FISH=true
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
# Copy .custom_bashrc (bash/zsh)
# ----------------------------
if [ -f "$LOCAL_CUSTOM_RC" ]; then
    echo ">>> Copying custom_bashrc to home..."
    cp "$LOCAL_CUSTOM_RC" "$CUSTOM_RC"
else
    echo ">>> Downloading custom_bashrc from GitHub..."
    curl -fsSL "https://raw.githubusercontent.com/jebin2/omarchy_custom_config/main/custom_bashrc?t=$(date +%s)" -o "$CUSTOM_RC"
fi

# ----------------------------
# Ensure shell profile sources .custom_bashrc
# ----------------------------
echo ">>> Ensuring ~/.custom_bashrc is sourced in $SHELL_RC..."

if ! grep -q 'source ~/.custom_bashrc' "$SHELL_RC" 2>/dev/null; then
    cat << 'EOF' >> "$SHELL_RC"

# Load custom bash config
[ -f ~/.custom_bashrc ] && source ~/.custom_bashrc
EOF
else
    echo "✔ ~/.custom_bashrc already sourced in $SHELL_RC"
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
    cat << 'EOF' > /tmp/pyenv_setup.txt
# >>> pyenv setup >>>
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv >/dev/null; then
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
fi
# <<< pyenv setup <<<

EOF
    touch "$CUSTOM_RC"
    cat /tmp/pyenv_setup.txt "$CUSTOM_RC" > "$CUSTOM_RC.tmp" && mv "$CUSTOM_RC.tmp" "$CUSTOM_RC"
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
