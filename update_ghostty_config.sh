#!/bin/bash

CONFIG_FILE="$HOME/.config/ghostty/config"
KEYBIND_LINE="keybind = ctrl+shift+r=reset"

# Check if the keybind line already exists
if ! grep -Fxq "$KEYBIND_LINE" "$CONFIG_FILE"; then
  # Append the keybind line with a comment
  echo -e "\n# To reset the terminal buffer and state\n$KEYBIND_LINE" >>"$CONFIG_FILE"
  echo "Keybind added to $CONFIG_FILE"
else
  echo "Keybind already present in $CONFIG_FILE"
fi
