#!/bin/bash

set -e

CUSTOM_RC="$HOME/.omarchy_custom_bashrc"
MAIN_RC="$HOME/.bashrc"

echo ">>> Ensuring custom Omarchy bashrc exists..."
touch "$CUSTOM_RC"

echo ">>> Adding sourcing line to $MAIN_RC if missing..."
if ! grep -q 'omarchy_custom_bashrc' "$MAIN_RC"; then
cat << 'EOF' >> "$MAIN_RC"

# Load Omarchy custom configuration
if [ -f "$HOME/.omarchy_custom_bashrc" ]; then
    source "$HOME/.omarchy_custom_bashrc"
fi
EOF
else
    echo "Sourcing entry already exists in $MAIN_RC."
fi

echo ">>> Done!"
echo "Custom file: $CUSTOM_RC"
echo "Main bashrc updated: $MAIN_RC"
