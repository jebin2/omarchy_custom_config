#!/bin/bash

# Array of filenames in current directory (modify with your specific filenames if needed)
files=("config.jsonc" "windows11-vm.desktop" "cheatsheet/omarchy-user-custom-config-cheatsheet")  # Replace with your actual filenames

# Loop over each file
for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        # Replace '/home/jebin/git/' with current working directory
        sed -i "s|/home/jebin/git/omarchy_custom_config/|$PWD/|g" "$file"
        echo "Updated $file"
    else
        echo "File $file does not exist, skipping."
    fi
done
