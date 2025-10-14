#!/bin/bash

CHEATSHEET_SRC="cheatsheet/omarchy-user-custom-config-cheatsheet"
CHEATSHEET_DST="$HOME/.local/share/omarchy/bin/omarchy-user-custom-config-cheatsheet"
OMARCHY_MENU="$HOME/.local/share/omarchy/bin/omarchy-menu"

read -p "Install cheatsheet? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    # 1. Make the cheatsheet executable
    chmod +x "$CHEATSHEET_SRC"
    
    # 2. Copy it to destination
    cp "$CHEATSHEET_SRC" "$CHEATSHEET_DST"
    echo "Copied $CHEATSHEET_SRC to $CHEATSHEET_DST"

    # 3. Update omarchy-menu if needed
    if ! grep -q "omarchy-user-custom-config-cheatsheet" "$OMARCHY_MENU"; then
        # Create a timestamp
        TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

        # Backup with timestamp
        BACKUP="$OMARCHY_MENU-omarchy-user-custom-config-cheatsheet-$TIMESTAMP.bak"
        cp "$OMARCHY_MENU" "$BACKUP"
        chmod -x "$BACKUP"
        echo "Backup created at $BACKUP"


        # 4. Insert line after the one containing 'omarchy-menu-keybindings'
        sed -i "/omarchy-menu-keybindings/a \ \ *Cheatsheet*) terminal omarchy-user-custom-config-cheatsheet ;;" "$OMARCHY_MENU"

        # 5. Replace " Keybindings\n" with " Keybindings\n Cheatsheet\n"
        # Note:  is Unicode U+F0AD
        sed -i 's/ Keybindings\\n/ Keybindings\\n Cheatsheet\\n/' "$OMARCHY_MENU"

        echo "Updated $OMARCHY_MENU"
    else
        echo "$OMARCHY_MENU already contains cheatsheet entry, skipping update."
    fi
else
    echo "Installation cancelled."
fi
