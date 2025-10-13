#!/bin/bash

# Get VRAM used and total
vram_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null)
vram_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null)

# Check if values are numbers; if not, set to 0
if ! [[ "$vram_used" =~ ^[0-9]+$ ]]; then
  vram_used=0
fi

if ! [[ "$vram_total" =~ ^[0-9]+$ ]]; then
  vram_total=0
fi

# Calculate percentage (avoid division by zero)
if [ "$vram_total" -ne 0 ]; then
  vram_percent=$((100 * vram_used / vram_total))
else
  vram_percent=0
fi

echo "VRAM: ${vram_used}M/${vram_total}M  "
