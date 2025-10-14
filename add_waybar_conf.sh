#!/bin/bash
set -e

EXISTING="$HOME/.config/waybar/config.jsonc"
UPDATE="config.jsonc"
BACKUP="${EXISTING%.*}-$(date +"%Y%m%d-%H%M%S").bak"

# Ensure jq exists
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required (install: sudo pacman -S jq)"
  exit 1
fi

# Check files
[[ -f "$EXISTING" && -f "$UPDATE" ]] || {
  echo "❌ Missing $EXISTING or $UPDATE"
  exit 1
}

# Backup
cp "$EXISTING" "$BACKUP"
chmod -x "$BACKUP"
echo "📦 Backup created at: $BACKUP"

# Function: Clean JSONC → valid JSON
clean_jsonc() {
  perl -0777 -pe '
    s!/\*.*?\*/!!gs;        # remove /* ... */
    s!//.*?$!!gm;           # remove // ...
    s/,\s*([}\]])/\1/g;     # remove trailing commas
  ' "$1"
}

CLEAN_EXISTING=$(mktemp)
CLEAN_UPDATE=$(mktemp)

clean_jsonc "$EXISTING" > "$CLEAN_EXISTING"
clean_jsonc "$UPDATE" > "$CLEAN_UPDATE"

# Validate both
jq empty "$CLEAN_EXISTING" >/dev/null 2>&1 || { echo "❌ Existing config invalid after cleaning"; exit 1; }
jq empty "$CLEAN_UPDATE" >/dev/null 2>&1 || { echo "❌ Update file invalid JSON"; exit 1; }

# ✅ Merge with order preservation
jq -s '
  reduce .[1:][] as $upd (.[0];
    # For modules-left: append new items to END
    .["modules-left"] = (
      (.["modules-left"] // []) + 
      (($upd["modules-left"] // []) - (.["modules-left"] // []))
    ) |
    # For modules-right: prepend new items to START
    .["modules-right"] = (
      (($upd["modules-right"] // []) - (.["modules-right"] // [])) + 
      (.["modules-right"] // [])
    ) |
    # Merge other top-level keys normally
    . * ($upd | del(.["modules-left", "modules-right"]))
  )
' "$CLEAN_EXISTING" "$CLEAN_UPDATE" > "${EXISTING}.tmp"

# Replace original
mv "${EXISTING}.tmp" "$EXISTING"
rm -f "$CLEAN_EXISTING" "$CLEAN_UPDATE"

echo "✅ Successfully merged updates from $UPDATE into $EXISTING"
omarchy-restart-waybar