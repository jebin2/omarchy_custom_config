#!/bin/bash

# Get all windows (id + title)
windows=$(hyprctl clients -j | jq -r '.[] | "\(.address)\t\(.title)"')

# Build menu with just titles (gum will return the full line)
chosen=$(echo -e "$windows" | gum choose --height 20 --cursor="👉" --header "Select a window to focus")

# If selection was made
if [[ -n "$chosen" ]]; then
  win_id=$(echo "$chosen" | awk '{print $1}')
  hyprctl dispatch focuswindow address:"$win_id"
fi
