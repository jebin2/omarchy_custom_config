#!/bin/bash
# Fish swimming continuously forward
frames=(
    "              🐟"
    "             🐟 "
    "            🐟  "
    "           🐟   "
    "          🐟    "
    "         🐟     "
    "        🐟      "
    "       🐟       "
    "      🐟        "
    "     🐟         "
    "    🐟          "
    "   🐟           "
    "  🐟            "
    " 🐟             "
    "🐟              "
)

index=0

while true; do
    echo "${frames[$index]}"
    index=$(((index + 1) % ${#frames[@]}))
    sleep 0.2
done