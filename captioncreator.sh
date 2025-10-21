#!/bin/bash

PYENV_ROOT="$HOME/.pyenv"
PYTHON_VERSION="CaptionCreator_env"
SCRIPT="/home/jebin/git/CaptionCreator/server.py"
PORT=3000

# Glyphs
ICON_RUNNING="©️  "
ICON_STOPPED="©️💤 "

# Activate pyenv environment
export PYENV_ROOT="$PYENV_ROOT"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv activate "$PYTHON_VERSION"

# Find running script
PID=$(pgrep -f "python.*$SCRIPT")

# Check if port is in use
PORT_ACTIVE=$(ss -tuln | grep -q ":$PORT " && echo 1 || echo 0)

MODE="$1"

case "$MODE" in
    1)
        # Only check status
        if [ -n "$PID" ] || [ "$PORT_ACTIVE" -eq 1 ]; then
            echo "$ICON_RUNNING"
        else
            echo "$ICON_STOPPED"
        fi
        ;;
    2)
        # Kill if running; if not running, start
        if [ -n "$PID" ] || [ "$PORT_ACTIVE" -eq 1 ]; then
            echo "$ICON_STOPPED"
            [ -n "$PID" ] && kill $PID
            sleep 1
            notify-send "CaptionCreator Stopped"
        else
            echo "$ICON_RUNNING"
            # Run script in background
            cd /home/jebin/git/CaptionCreator || exit
            python "$SCRIPT" >> /dev/null 2>&1 &
            notify-send "CaptionCreator Started"
        fi
        ;;
    *)
        echo "Usage: $0 [1|2]"
        echo "1 = Check status only"
        echo "2 = Kill if running; start if not running"
        ;;
esac
