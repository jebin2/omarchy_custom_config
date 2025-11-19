#!/usr/bin/env bash

echo "=== Cloudflare WARP Manager for Arch Linux ==="

# Check if warp-cli exists
if ! command -v warp-cli &> /dev/null; then
    echo "WARP is not installed. Installing..."
    if command -v yay &> /dev/null; then
        yay -S cloudflare-warp-bin --noconfirm
    elif command -v paru &> /dev/null; then
        paru -S cloudflare-warp-bin --noconfirm
    else
        echo "No AUR helper (yay/paru) found. Install WARP manually."
        exit 1
    fi
fi

echo "WARP is already installed."

# Ensure daemon exists
if ! systemctl list-unit-files | grep -q warp-svc; then
    echo "Error: warp-svc daemon not found. Your WARP installation may be corrupted."
    exit 1
fi

echo "Choose:"
echo "1) Turn WARP ON"
echo "2) Turn WARP OFF"
read -rp "Enter choice (1/2): " choice

if [[ "$choice" == "1" ]]; then
    echo "=== Turning WARP ON ==="

    # Enable + start daemon immediately
    sudo systemctl enable --now warp-svc

    sleep 1

    # Check registration
    if warp-cli --accept-tos status | grep -q "Registration missing"; then
        echo "Registering new WARP identity..."
        warp-cli --accept-tos registration new
    fi

    # Connect WARP
    warp-cli --accept-tos connect

    warp-cli --accept-tos status
    echo "Visit1️⃣: https://one.one.one.one/help/"
    exit 0
fi


if [[ "$choice" == "2" ]]; then
    echo "=== Turning WARP OFF ==="

    if systemctl is-active --quiet warp-svc; then
        warp-cli --accept-tos disconnect 2>/dev/null || true
        sudo systemctl stop warp-svc
    else
        echo "Daemon already stopped. WARP is OFF."
    fi

    echo "WARP is now OFF."
    echo "Visit1️⃣: https://one.one.one.one/help/"
    exit 0
fi

echo "Invalid choice."
exit 1
