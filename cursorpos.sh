#!/bin/bash
# Ultra-optimized cursor position logger with archiving
# Combines performance of FD reuse with history preservation
# Save as: /home/jebin/git/omarchy_custom_config/cursorpos.sh

LOGFILE="/home/jebin/git/omarchy_custom_config/cursor_positions.log"
MAXSIZE=$((100 * 1024 * 1024))  # 100 MB in bytes

# Function to handle log rotation with archiving
rotate_log() {
    if [[ -f "$LOGFILE" ]]; then
        read -r last_mod filesize < <(stat -c '%Y %s' "$LOGFILE")
        today=$(date '+%s')
        day_start=$((today - today % 86400))
        
        if (( last_mod < day_start || filesize > MAXSIZE )); then
            # Archive old log with timestamp (background compression)
            archive_name="${LOGFILE}.$(date -r "$LOGFILE" '+%Y-%m-%d_%H-%M-%S')"
            mv "$LOGFILE" "$archive_name" && gzip "$archive_name" &
            
            # Close and reopen file descriptor
            exec 3>&-
            > "$LOGFILE"
            exec 3>>"$LOGFILE"
            return 0
        fi
    else
        > "$LOGFILE"
    fi
    return 1
}

# Initial setup
rotate_log
[[ -f "$LOGFILE" ]] || > "$LOGFILE"

# Pre-open file descriptor for fast writes
exec 3>>"$LOGFILE"

# Cache last position
last_x=""
last_y=""
write_count=0

# Main loop
while true; do
    # Read cursor position directly into variables
    IFS=',' read -r x y < <(hyprctl cursorpos 2>/dev/null) || {
        printf '󰇀 --,--\n'
        sleep 0.1
        continue
    }
    
    # Remove spaces efficiently
    x=${x// /}
    y=${y// /}
    
    # Only log if position changed
    if [[ "$x" != "$last_x" || "$y" != "$last_y" ]]; then
        # Batch size checks every 1000 writes (huge performance gain)
        if (( ++write_count % 1000 == 0 )); then
            rotate_log
        fi
        
        # Fast write using pre-opened file descriptor
        printf '%s,%s,%s\n' "$(date +%s)" "$x" "$y" >&3
        
        last_x="$x"
        last_y="$y"
    fi
    
    printf '󰇀 %s,%s\n' "$x" "$y"
    
    sleep 0.1
done

# Cleanup (won't reach here, but good practice)
exec 3>&-
