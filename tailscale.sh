#!/bin/bash

# Check if Tailscale is connected
if tailscale status &>/dev/null; then
  echo "┇┇┇  " #᎒᎒᎒ connected icon
else
  echo "𓃑  " #𝗓ᶻ disconnected icon
fi