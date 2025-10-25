#!/bin/bash
# Ultra-lightweight cursor position logger (no duplicate positions)
# Save as: /home/jebin/git/omarchy_custom_config/cursorpos.sh
# chmod +x /home/jebin/git/omarchy_custom_config/cursorpos.sh

LOGFILE="/home/jebin/git/omarchy_custom_config/cursor_positions.log"
touch "$LOGFILE"

# Cache last position in memory (fastest method)
last_x=""
last_y=""

while true; do
    pos=$(hyprctl cursorpos 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        x=$(echo "$pos" | cut -d',' -f1 | tr -d ' ')
        y=$(echo "$pos" | cut -d',' -f2 | tr -d ' ')
        
        # Only log if position changed (memory comparison - ZERO overhead)
        if [ "$x" != "$last_x" ] || [ "$y" != "$last_y" ]; then
            timestamp=$(date '+%s')
            echo "$timestamp,$x,$y" >> "$LOGFILE"
            last_x="$x"
            last_y="$y"
        fi
        
        echo "󰇀 $x,$y"
    else
        echo "󰇀 --,--"
    fi
    
    sleep 0.1
done