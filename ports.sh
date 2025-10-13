#!/bin/bash

# Get only listening ports (ip:port)
PORTS=$(ss -tulnp 2>/dev/null | awk 'NR>1 {print $5}' | head -n 20)

# Cache index
CACHE=/tmp/waybar_ports_index
[ -f "$CACHE" ] || echo 0 >"$CACHE"
INDEX=$(cat "$CACHE")

COUNT=$(echo "$PORTS" | wc -l)
[ "$COUNT" -eq 0 ] && echo "No Ports" && exit 0

# Rotate index
INDEX=$((INDEX % COUNT))

# Pick one port
PORT=$(echo "$PORTS" | sed -n "$((INDEX + 1))p")

echo "$PORT  "

# Save next index
echo $((INDEX + 1)) >"$CACHE"
