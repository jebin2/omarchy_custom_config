#!/bin/bash
vram_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
vram_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
vram_percent=$((100 * vram_used / vram_total))
echo "VRAM: ${vram_used}M/${vram_total}M  "
