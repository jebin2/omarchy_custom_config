#!/bin/bash

set -e

CUSTOM_RC="$HOME/.omarchy_custom_zshrc"
MAIN_RC="$HOME/.zshrc"

echo ">>> Ensuring custom Omarchy zshrc exists..."
touch "$CUSTOM_RC"

echo ">>> Adding sourcing line to $MAIN_RC if missing..."
if ! grep -q 'omarchy_custom_zshrc' "$MAIN_RC"; then
cat << 'EOF' >> "$MAIN_RC"

# Load Omarchy custom configuration
if [ -f "$HOME/.omarchy_custom_zshrc" ]; then
    source "$HOME/.omarchy_custom_zshrc"
fi
EOF
else
    echo "Sourcing entry already exists in $MAIN_RC."
fi

echo ">>> Done!"
echo "Custom file: $CUSTOM_RC"
echo "Main zshrc updated: $MAIN_RC"
