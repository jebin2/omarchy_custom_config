#!/bin/bash

# Check if Tailscale is connected
if tailscale status &>/dev/null; then
  echo "🔗 Tailscale  " # connected icon
else
  echo "❌ Tailscale  " # disconnected icon
fi
